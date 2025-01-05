// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title AstralNexusItems
 * @dev NFT contract for game items with enhanced security and role-based access
 */
contract AstralNexusItems is ERC721Enumerable, AccessControl, Pausable {
    using Counters for Counters.Counter;
    
    bytes32 public constant GAME_ADMIN = keccak256("GAME_ADMIN");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    Counters.Counter private _tokenIds;
    
    enum Rarity { Common, Uncommon, Rare, Epic, Legendary }
    enum ItemType { Weapon, Armor, Accessory, Consumable, QuestItem, CraftingMaterial }
    
    struct Item {
        string name;
        ItemType itemType;
        Rarity rarity;
        uint256 level;
        uint256[] stats;
        mapping(string => string) properties;
        bool tradeable;
        bool soulbound;
    }
    
    // Storage
    mapping(uint256 => Item) private _items;
    mapping(uint256 => bool) private _equipped;
    mapping(address => uint256) private _equippedItemsCount;
    uint256 public constant MAX_EQUIPPED_ITEMS = 20;
    
    // Events
    event ItemCreated(uint256 indexed tokenId, address indexed owner, string name, ItemType itemType, Rarity rarity);
    event ItemEquipped(uint256 indexed tokenId, address indexed owner);
    event ItemUnequipped(uint256 indexed tokenId, address indexed owner);
    event ItemPropertyUpdated(uint256 indexed tokenId, string key, string value);
    
    constructor() ERC721("Astral Nexus Items", "ANI") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GAME_ADMIN, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }
    
    modifier onlyGameAdmin() {
        require(hasRole(GAME_ADMIN, msg.sender), "Caller is not a game admin");
        _;
    }
    
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _;
    }
    
    function createItem(
        address player,
        string memory name,
        ItemType itemType,
        Rarity rarity,
        uint256 level,
        uint256[] memory stats,
        string[] memory propertyNames,
        string[] memory propertyValues,
        bool tradeable,
        bool soulbound
    ) external onlyMinter whenNotPaused returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(propertyNames.length == propertyValues.length, "Property arrays must be equal length");
        require(stats.length <= 10, "Too many stats");
        
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        
        Item storage newItem = _items[newItemId];
        newItem.name = name;
        newItem.itemType = itemType;
        newItem.rarity = rarity;
        newItem.level = level;
        newItem.stats = stats;
        newItem.tradeable = tradeable;
        newItem.soulbound = soulbound;
        
        for (uint256 i = 0; i < propertyNames.length; i++) {
            newItem.properties[propertyNames[i]] = propertyValues[i];
        }
        
        _safeMint(player, newItemId);
        emit ItemCreated(newItemId, player, name, itemType, rarity);
        
        return newItemId;
    }
    
    function getItemBasicInfo(uint256 tokenId) external view returns (
        string memory name,
        ItemType itemType,
        Rarity rarity,
        uint256 level
    ) {
        require(_exists(tokenId), "Item does not exist");
        Item storage item = _items[tokenId];
        
        return (
            item.name,
            item.itemType,
            item.rarity,
            item.level
        );
    }

    function getItemExtendedInfo(uint256 tokenId) external view returns (
        uint256[] memory stats,
        bool tradeable,
        bool soulbound,
        bool equipped
    ) {
        require(_exists(tokenId), "Item does not exist");
        Item storage item = _items[tokenId];
        
        return (
            item.stats,
            item.tradeable,
            item.soulbound,
            _equipped[tokenId]
        );
    }
    
    function getItemProperty(uint256 tokenId, string calldata key) external view returns (string memory) {
        require(_exists(tokenId), "Item does not exist");
        return _items[tokenId].properties[key];
    }
    
    function _canEquipItem(uint256 tokenId, address owner) private view returns (bool) {
        return ownerOf(tokenId) == owner && 
               !_equipped[tokenId] && 
               _equippedItemsCount[owner] < MAX_EQUIPPED_ITEMS;
    }

    function _canUnequipItem(uint256 tokenId, address owner) private view returns (bool) {
        return ownerOf(tokenId) == owner && _equipped[tokenId];
    }
    
    function equipItem(uint256 tokenId) external whenNotPaused {
        require(_canEquipItem(tokenId, msg.sender), "Cannot equip item");
        
        _equipped[tokenId] = true;
        _equippedItemsCount[msg.sender]++;
        emit ItemEquipped(tokenId, msg.sender);
    }
    
    function unequipItem(uint256 tokenId) external whenNotPaused {
        require(_canUnequipItem(tokenId, msg.sender), "Cannot unequip item");
        
        _equipped[tokenId] = false;
        _equippedItemsCount[msg.sender]--;
        emit ItemUnequipped(tokenId, msg.sender);
    }
    
    function isEquipped(uint256 tokenId) external view returns (bool) {
        require(_exists(tokenId), "Item does not exist");
        return _equipped[tokenId];
    }
    
    function equippedItemsCount(address owner) external view returns (uint256) {
        return _equippedItemsCount[owner];
    }
    
    function updateItemProperty(
        uint256 tokenId,
        string calldata key,
        string calldata value
    ) external onlyGameAdmin whenNotPaused {
        require(_exists(tokenId), "Item does not exist");
        _items[tokenId].properties[key] = value;
        emit ItemPropertyUpdated(tokenId, key, value);
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        
        if (from != address(0) && to != address(0)) {
            require(_items[tokenId].tradeable, "Item not tradeable");
            require(!_items[tokenId].soulbound, "Item is soulbound");
            require(!_equipped[tokenId], "Item is equipped");
        }
    }
    
    function pause() external onlyGameAdmin {
        _pause();
    }
    
    function unpause() external onlyGameAdmin {
        _unpause();
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

/**
 * @title AstralNexusCharacter
 * @dev Character NFT contract with improved progression system
 */
contract AstralNexusCharacter is ERC721URIStorage, AccessControl, Pausable {
    using Counters for Counters.Counter;
    
    bytes32 public constant GAME_ADMIN = keccak256("GAME_ADMIN");
    Counters.Counter private _tokenIds;
    
    struct Character {
        string class;
        uint256 level;
        uint256 exp;
        uint256[] equippedItems;
        uint256 lastLogin;
        mapping(string => uint256) attributes;
    }
    
    mapping(uint256 => Character) private _characters;
    mapping(address => uint256) private _playerCharacters;
    
    event CharacterCreated(uint256 indexed tokenId, address indexed owner, string class);
    event CharacterProgression(uint256 indexed tokenId, uint256 newLevel, uint256 newExp);
    event AttributeUpdated(uint256 indexed tokenId, string attribute, uint256 value);
    
    constructor() ERC721("AstralNexusCharacter", "CHAR") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GAME_ADMIN, msg.sender);
    }
    
    modifier onlyGameAdmin() {
        require(hasRole(GAME_ADMIN, msg.sender), "Caller is not a game admin");
        _;
    }
    
    function createCharacter(
        address player,
        string calldata characterClass,
        string[] calldata attributeNames,
        uint256[] calldata attributeValues
    ) external onlyGameAdmin whenNotPaused returns (uint256) {
        require(_playerCharacters[player] == 0, "Player already has character");
        require(attributeNames.length == attributeValues.length, "Array length mismatch");
        
        _tokenIds.increment();
        uint256 newCharacterId = _tokenIds.current();
        
        Character storage character = _characters[newCharacterId];
        character.class = characterClass;
        character.level = 1;
        character.exp = 0;
        character.lastLogin = block.timestamp;
        
        for (uint256 i = 0; i < attributeNames.length; i++) {
            character.attributes[attributeNames[i]] = attributeValues[i];
        }
        
        _safeMint(player, newCharacterId);
        _playerCharacters[player] = newCharacterId;
        
        emit CharacterCreated(newCharacterId, player, characterClass);
        return newCharacterId;
    }
    
    function updateProgress(
        uint256 characterId,
        uint256 expGained
    ) external onlyGameAdmin whenNotPaused {
        require(_exists(characterId), "Character does not exist");
        
        Character storage character = _characters[characterId];
        character.exp += expGained;
        
        uint256 expNeeded = character.level * 1000;
        while (character.exp >= expNeeded) {
            character.exp -= expNeeded;
            character.level++;
            expNeeded = character.level * 1000;
        }
        
        emit CharacterProgression(characterId, character.level, character.exp);
    }
    
    function updateAttribute(
        uint256 characterId,
        string calldata attribute,
        uint256 value
    ) external onlyGameAdmin whenNotPaused {
        require(_exists(characterId), "Character does not exist");
        _characters[characterId].attributes[attribute] = value;
        emit AttributeUpdated(characterId, attribute, value);
    }
    
    function getCharacter(uint256 characterId) external view returns (
        string memory class,
        uint256 level,
        uint256 exp,
        uint256[] memory equippedItems,
        uint256 lastLogin
    ) {
        require(_exists(characterId), "Character does not exist");
        Character storage character = _characters[characterId];
        
        return (
            character.class,
            character.level,
            character.exp,
            character.equippedItems,
            character.lastLogin
        );
    }
    
    function getAttribute(
        uint256 characterId,
        string calldata attribute
    ) external view returns (uint256) {
        require(_exists(characterId), "Character does not exist");
        return _characters[characterId].attributes[attribute];
    }
    
    function pause() external onlyGameAdmin {
        _pause();
    }
    
    function unpause() external onlyGameAdmin {
        _unpause();
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

/**
 * @title AstralNexusToken
 * @dev Game token with enhanced security and minting controls
 */
contract AstralNexusToken is ERC20Burnable, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    constructor(uint256 initialSupply) ERC20("Astral Nexus Token", "ANT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
    
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "Token transfers paused");
    }
}

/**
 * @title AstralNexusExchange
 * @dev Token exchange with improved security and rate management
 */
contract AstralNexusExchange is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant RATE_MANAGER_ROLE = keccak256("RATE_MANAGER_ROLE");
    
    IERC20 public immutable gameToken;
    IERC20 public immutable eduToken;
    
    uint256 public rateGameToEdu;
    uint256 public rateEduToGame;
    uint256 public constant RATE_PRECISION = 1e18;
    
    event TokensSwapped(
        address indexed user,
        uint256 amountIn,
        uint256 amountOut,
        bool isGameToEdu
    );
    event RatesUpdated(uint256 newRateGameToEdu, uint256 newRateEduToGame);
    
    constructor(
        address _gameToken,
        address _eduToken,
        uint256 _rateGameToEdu,
        uint256 _rateEduToGame
    ) {
        require(_gameToken != address(0) && _eduToken != address(0), "Zero address");
        require(_rateGameToEdu > 0 && _rateEduToGame > 0, "Invalid rates");
        
        gameToken = IERC20(_gameToken);
        eduToken = IERC20(_eduToken);
        rateGameToEdu = _rateGameToEdu;
        rateEduToGame = _rateEduToGame;
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(RATE_MANAGER_ROLE, msg.sender);
    }
    
    function updateRates(
        uint256 _rateGameToEdu,
        uint256 _rateEduToGame
    ) external onlyRole(RATE_MANAGER_ROLE) {
        require(_rateGameToEdu > 0 && _rateEduToGame > 0, "Invalid rates");
        rateGameToEdu = _rateGameToEdu;
        rateEduToGame = _rateEduToGame;
        emit RatesUpdated(_rateGameToEdu, _rateEduToGame);
    }
    
    function convertGameToEdu(
        uint256 gameAmount
    ) external nonReentrant whenNotPaused {
        require(gameAmount > 0, "Amount must be greater than 0");
        
        uint256 eduAmount = (gameAmount * rateGameToEdu) / RATE_PRECISION;
        require(eduAmount > 0, "Output amount too small");
        
        uint256 eduBalance = eduToken.balanceOf(address(this));
        require(eduBalance >= eduAmount, "Insufficient EDU balance");
        
        bool success1 = gameToken.transferFrom(msg.sender, address(this), gameAmount);
        require(success1, "Game token transfer failed");
        
        bool success2 = eduToken.transfer(msg.sender, eduAmount);
        require(success2, "EDU token transfer failed");
        
        emit TokensSwapped(msg.sender, gameAmount, eduAmount, true);
    }
    
    function convertEduToGame(
        uint256 eduAmount
    ) external nonReentrant whenNotPaused {
        require(eduAmount > 0, "Amount must be greater than 0");
        
        uint256 gameAmount = (eduAmount * rateEduToGame) / RATE_PRECISION;
        require(gameAmount > 0, "Output amount too small");
        
        uint256 gameBalance = gameToken.balanceOf(address(this));
        require(gameBalance >= gameAmount, "Insufficient Game balance");
        
        bool success1 = eduToken.transferFrom(msg.sender, address(this), eduAmount);
        require(success1, "EDU token transfer failed");
        
        bool success2 = gameToken.transfer(msg.sender, gameAmount);
        require(success2, "Game token transfer failed");
        
        emit TokensSwapped(msg.sender, eduAmount, gameAmount, false);
    }
    
    function withdrawTokens(
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token == address(gameToken) || token == address(eduToken), "Invalid token");
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}