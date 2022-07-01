// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

interface IERC20Ext is IERC20 {
  function decimals() external view returns(uint8);
}

contract GoldMintNFT is ERC721EnumerableUpgradeable, OwnableUpgradeable {
  using StringsUpgradeable for uint;

  event Deposit(address who, uint256 amount);
  event GoldMint(address to);
  event Reveal(address who, uint256 tokenId, uint rarity);

  // tiers
  uint CHEST;
  uint BAR;
  uint SACK;
  uint COIN;

  // structure of representing properties of every tier
  struct Tier {
    string    name;
    uint256   rewards;
    uint      limit;
    uint      minted;
  }

  struct NFTInfo {
    uint256   mintTime;
    uint      rarity;
    bool      revealed;
  }

  // tier overviews
  mapping(uint => Tier) public tiers;
  // payment token
  IERC20Ext public tokenForPayment;
  // mint rewards
  uint256 public mintPrice;
  // dev wallet
  address public devWallet;
  // total mintable number
  uint public total_mintables;
  mapping(uint => uint) public random_map;
  // inited flag
  bool inited;
  // base uri
  string public baseURI;
  string public dummyURI;
  // NFT info
  mapping(uint256 => NFTInfo) public nfts;
  // reveal time
  uint256 revealTime;
  // max supply
  uint256 maxSupply;

  // initialize
  function init(address _devWallet, string memory baseURI_, uint256 revealTime_) internal {
    CHEST = 1;
    BAR = 2;
    SACK = 3;
    COIN = 4;
    tiers[CHEST].name="Chest";
    tiers[CHEST].limit = 2;

    tiers[BAR].name="Bar";
    tiers[BAR].limit = 8;

    tiers[SACK].name="Sack";
    tiers[SACK].limit = 20;

    tiers[COIN].name="Coin";
    tiers[COIN].limit = 40;

    uint i = 0;
    maxSupply = 0;
    for(i = CHEST; i <= COIN; i ++)
      maxSupply += tiers[i].limit;

    devWallet = _devWallet;
    mintPrice = 0.4 ether; // 0.4

    uint base = 0;
    for (i = 0; i < tiers[CHEST].limit; i ++)
      random_map[i] = CHEST;
    base = i;
    for (; i < base + tiers[BAR].limit; i ++)
      random_map[i] = BAR;
    base = i;
    for (; i < base + tiers[SACK].limit; i ++)
      random_map[i] = SACK;
    base = i;
    for (; i < base + tiers[COIN].limit; i ++)
      random_map[i] = COIN;
    total_mintables = i;
    inited = false;
    baseURI = baseURI_;
    revealTime = revealTime_;
    dummyURI = "";
  }

  // initialize
  function initialize(
    string memory name_, 
    string memory symbol_, 
    string memory baseURI_, 
    uint256 revealTime_, 
    address _devWallet) public initializer 
  {
    __Ownable_init();
    __ERC721_init(name_, symbol_);
    init(_devWallet, baseURI_, revealTime_);
  }

  // set uri
  function setBaseURI(string memory baseURI_) public onlyOwner {
    baseURI = baseURI_;
  }

  function setDummyURI(string memory dummyURI_) public onlyOwner {
    dummyURI = dummyURI_;
  }

  // set reaveal duration 
  function setRevealTime(uint256 duration) public onlyOwner{
    revealTime = duration;
  }

  // base uri
  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  // set payment token
  function setPaymentToken(address _tokenaddr) public onlyOwner {
    tokenForPayment = IERC20Ext(_tokenaddr);
    uint8 decimals = tokenForPayment.decimals() - 1;
    uint256 unit = 10**decimals; 
    mintPrice = 4*unit; // 0.4 ether
    tiers[CHEST].rewards = 25*unit;  // 2.5 ether
    tiers[BAR].rewards = 10*unit;    // 1 ether
    tiers[SACK].rewards = 2*unit;    // 0.2 ether
    tiers[COIN].rewards = 1*unit;    // 0.1 ether
    inited = true;
  }

  // set development wallet
  function setDevWallet(address wallet) public onlyOwner {
    devWallet = wallet;
  }

  // deposit token for reward
  function deposit() public {
    // calculate amount of deposit
    uint256 amount = 
      (tiers[CHEST].limit * tiers[CHEST].rewards) +
      (tiers[BAR].limit * tiers[BAR].rewards) +
      (tiers[SACK].limit * tiers[SACK].rewards) +
      (tiers[COIN].limit * tiers[COIN].rewards);

    require(tokenForPayment.balanceOf(msg.sender) >= amount, "Insufficient funds to deposit!");
    tokenForPayment.transferFrom(msg.sender, address(this), amount);
    
    emit Deposit(msg.sender, amount);
  }

  // generate random tier
  function getRandomizedTier() public view returns(uint) {
    uint randomNumber = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
    uint rndScaleIn = randomNumber % total_mintables;
    uint id;
    
    for(id = random_map[rndScaleIn]; id <= COIN; id ++)
    {
      Tier storage t = tiers[id];
      if (t.minted < t.limit)
        return id;
    }

    for(id = random_map[rndScaleIn]; id >= CHEST; id --)
    {
      Tier storage t = tiers[id];
      if (t.minted < t.limit)
        return id;
    }

    return 0;
  }

  // mint
  function mint() public returns(uint){
    require(inited == true, "Contract is not inited yet!");
    require(
      tokenForPayment.balanceOf(msg.sender) >= mintPrice,
      "[MINT] Insufficient funds to mint!"
    );
    uint256 tokenId = totalSupply() + 1;
    uint id = getRandomizedTier();
    require(id != 0, "All NFTs are minted. Not able to mint anymore!");
    
    // payment for mint
    tokenForPayment.transferFrom(msg.sender, devWallet, mintPrice);
    // setting nft info
    nfts[tokenId].mintTime = block.timestamp;
    nfts[tokenId].rarity = id;
    // setting tiers mint count
    tiers[id].minted += 1;
    // mint
    _mint(msg.sender, tokenId);
    emit GoldMint(msg.sender);
    return id;
  }

  // token uri
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    uint rarity = nfts[tokenId].rarity;
    require (rarity == CHEST ||
        rarity == BAR ||
        rarity == SACK ||
        rarity == COIN, "GoldMintNFT: Unknown rarity!");

    if (!nfts[tokenId].revealed)
      return dummyURI;

    return string(abi.encodePacked(baseURI, rarity.toString(), ".json"));
  }

  // check if available to reveal
  function availeToReveal(uint256 tokenId) public view returns(bool){
    if (block.timestamp - nfts[tokenId].mintTime >= revealTime)
      return true;
    return false;
  }

  // reveal
  function reveal(uint256 tokenId) public {
    require(availeToReveal(tokenId), "GoldMintNFT: It's too early to reveal!");
    
    address tokenOwner = ownerOf(tokenId);
    require(tokenOwner == msg.sender, "GoldMintNFT: You are not the owner of this NFT!");
    nfts[tokenId].revealed = true;
    // send rewards
    uint rarity = nfts[tokenId].rarity;
    tokenForPayment.transfer(msg.sender, tiers[rarity].rewards);
    emit Reveal(msg.sender, tokenId, rarity);
  }

  // withdraw rest from this contract
  function withdrawAll() public onlyOwner {
    tokenForPayment.transfer(msg.sender, tokenForPayment.balanceOf(address(this)));
  }
}