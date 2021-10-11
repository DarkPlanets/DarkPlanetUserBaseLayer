/**
 *Submitted for verification at FtmScan.com on 2021-10-11
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }


    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


interface RarityLandStorage {
    function getLandFee(uint256 summoner)external view returns(bool,uint256);
    function getLandCoordinates(uint256 summoner) external view returns(bool,uint256 x,uint256 y);
    function getSummonerCoordinates(uint256 summoner)external view returns(bool,uint256 x,uint256 y);
    function getLandIndex(uint256 summoner)external view returns(bool result,uint256 landIndex);
    function getSummoner(uint256 lIndex)external view returns(bool result,uint256 summoner);
    function totalSupply() external view returns (uint256 supply);
}

interface rarity {
    function level(uint) external view returns (uint);
    function getApproved(uint) external view returns (address);
    function ownerOf(uint) external view returns (address);
    function summoner(uint) external view returns (uint _xp, uint _log, uint _class, uint _level);
}

contract DarkPlanetUserBaseLayer is Ownable {
    
    //main-Rarity: 0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb
    rarity constant rm = rarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
    address public rlsAddr;
    //Maximum number of summoners in a piece of land
    uint256 private _maxSummoners; 
    //In this cycle, the summoner needs to be activated once, otherwise, it will enter a dangerous state.
    uint256 private _activePeriod;

    struct summonerInfo {
        uint256 startActiveTime;
        uint256 lastActiveTime;
        //1-active, 0-dead
        uint256 state;
        uint256 currentLandIndex;
        uint256 currentLocationIndex;
    }
    //summoner -> summonerInfo
    mapping(uint256 => summonerInfo) private _summonersInfo;
    //land -> summonersAmount(<100)
    mapping(uint256 => uint256)private _landSummonersAmount;
    mapping(uint256 => uint256)private _indexSummoner;
    
    function isRarityOwner(uint256 summoner) internal view returns (bool) {
        address rarityAddress = rm.ownerOf(summoner);
        return rarityAddress == msg.sender;
    }

    function getRLS()internal view returns(RarityLandStorage){
        require(rlsAddr != address(0),"no rlsAddr .");
        return RarityLandStorage(rlsAddr);
    }

    function setRLS(address rls)public onlyOwner{
        rlsAddr = rls;
    }

    function setMaxSummoners(uint256 maxValue)public onlyOwner {
        _maxSummoners = maxValue;
    }
    

    function setActivePeriod(uint256 activePeriod)public onlyOwner {
        require(activePeriod > 0,"activePeriod error .");
        _activePeriod = activePeriod * 1 days;
    }
    
    
    function activate(uint256 summoner)public returns(bool){
        require(summoner != 0, "no support 0 .");
        require(isRarityOwner(summoner),"no owner .");
        (bool result,uint256 lIndex) = getLandLocationForSummoner(summoner);
        require(result,"(0,0),error .");
        summonerInfo memory sInfo = _summonersInfo[summoner];

        if( sInfo.state == 1 && 
            _landSummonersAmount[sInfo.currentLandIndex] > 0){
            if(lIndex == sInfo.currentLandIndex){
                sInfo.lastActiveTime = block.timestamp;
                _summonersInfo[summoner] = sInfo;
                return true;              
            }else{
                uint256 sLocation = sInfo.currentLandIndex * 100 + sInfo.currentLocationIndex;
                uint256 last_sLocation = sInfo.currentLandIndex * 100 + _landSummonersAmount[sInfo.currentLandIndex] - 1;
                if(sLocation == last_sLocation){
                    _indexSummoner[sLocation] = 0;
                }else{
                    _indexSummoner[sLocation] = _indexSummoner[last_sLocation];
                }
                _landSummonersAmount[sInfo.currentLandIndex] = _landSummonersAmount[sInfo.currentLandIndex] - 1;
            }
        }
        require(_landSummonersAmount[lIndex] < _maxSummoners, "Max value, error.");
        sInfo.startActiveTime = block.timestamp;
        sInfo.lastActiveTime = block.timestamp;
        sInfo.state = 1;
        sInfo.currentLandIndex = lIndex;
        sInfo.currentLocationIndex = _landSummonersAmount[lIndex];
        _summonersInfo[summoner] = sInfo;
        uint256 sIndex = lIndex * 100 + _landSummonersAmount[lIndex];
        _indexSummoner[sIndex] = summoner;
        _landSummonersAmount[lIndex] = _landSummonersAmount[lIndex] + 1;
        return true;
    }
    
    function exile(uint256 mySummoner,uint256 sIndex)public {
        require(mySummoner != 0, "no support 0 .");
        require(isRarityOwner(mySummoner),"no owner .");
        (bool result,uint256 lIndex) = getRLS().getLandIndex(mySummoner);
        require(result,"no land,error .");
        uint256 lsAmount = _landSummonersAmount[lIndex];
        require(sIndex < lsAmount,"exile,sIndex,error.");

        uint256 sLocation = lIndex * 100 + sIndex;
        uint256 summoner = _indexSummoner[sLocation];
        (,uint256 state) = getSummonerState(summoner);
        require(state != 1,"It is not a dangerous state. error !");
        summonerInfo memory sInfo = _summonersInfo[summoner];
        sInfo.state = 0;
        _summonersInfo[summoner] = sInfo;
        uint256 last_sLocation = lIndex * 100 + lsAmount - 1;
        if(sLocation == last_sLocation){
            _indexSummoner[sLocation] = 0;
        }else{
            _indexSummoner[sLocation] = _indexSummoner[last_sLocation];
        }
        _landSummonersAmount[lIndex] = _landSummonersAmount[lIndex] - 1;
    }
    

    function getLandLocationForSummoner(uint256 summoner) public view returns(bool,uint256){
        (,uint256 x,uint256 y) = getRLS().getSummonerCoordinates(summoner);
        if(x == 0 && y == 0){
            //invalid
            return(false,0);
        }
        uint256 lIndex = x / 1000;
        return(true,lIndex);
    }

    //0-dead,1-safe, 2-dangerous(time expired), 3-dangerous(location error)
    //severity: 0 > 3 > 2
    function getSummonerState(uint256 summoner)public view returns(bool,uint256 state){
        if(summoner == 0){
            return (false,0);
        }
        summonerInfo memory sInfo = _summonersInfo[summoner];
        if(sInfo.state == 0){
            return(true,0);
        }

        (,uint256 x,) = getRLS().getSummonerCoordinates(summoner);
        uint256 lIndex = x/1000;
        if(lIndex != sInfo.currentLandIndex){
            return(true,3);
        }
        if((block.timestamp - sInfo.lastActiveTime) > _activePeriod){
            return(true,2);
        }
        return (true,1);
    }
    
    //time unit: s
    function getSummonerTimeInfo(uint256 summoner)public view returns(
        bool result,
        uint256 state,
        uint256 sTime,
        uint256 lTime){

        if(summoner == 0){
            return (false,0,0,0);
        }
        (,uint256 s_state) = getSummonerState(summoner);
        summonerInfo memory sInfo = _summonersInfo[summoner];
        return(true,s_state,sInfo.startActiveTime,sInfo.lastActiveTime);
    }
    
    //time unit: s
    function getSummonerInfo(uint256 summoner)public view returns(
        bool r_result,
        uint256 r_state,
        uint256 tTime,
        uint256 rTime){

        if(summoner == 0){
            return (false,0,0,0);
        }
        (,uint256 state) = getSummonerState(summoner);
        summonerInfo memory sInfo = _summonersInfo[summoner];
        if(state == 0){
            return(true,0,0,0);
        }
        tTime = block.timestamp - sInfo.startActiveTime;
        uint256 intervalTime = block.timestamp - sInfo.lastActiveTime;
        if(intervalTime >= _activePeriod){
            return (true,state,tTime,0);
        }
        return (true,state,tTime,(_activePeriod-intervalTime));
    }
    
    
    function getSummonerTimeInfo_MyLand(uint256 mySummoner,uint256 sIndex)public view returns(
        bool r_result,
        uint256 r_state,
        uint256 sTime,
        uint256 lTime){
        
        if(mySummoner == 0){
            return (false,0,0,0);
        }
        (bool result,uint256 lIndex) = getRLS().getLandIndex(mySummoner);
        if(!result){
            return (false,0,0,0);
        }
        uint256 lsAmount = _landSummonersAmount[lIndex];
        if(sIndex >= lsAmount){
            return (false,0,0,0);
        }
        uint256 sLocation = lIndex * 100 + sIndex;
        uint256 summoner = _indexSummoner[sLocation];
        (,uint256 state) = getSummonerState(summoner);
        summonerInfo memory sInfo = _summonersInfo[summoner];
        return(true,state,sInfo.startActiveTime,sInfo.lastActiveTime);
    }
    
    function getSummonerInfo_MyLand(uint256 mySummoner,uint256 sIndex)public view returns(
        bool r_result,
        uint256 r_state,
        uint256 tTime,
        uint256 rTime){
    
        if(mySummoner == 0){
            return (false,0,0,0);
        }
       
        (bool result,uint256 lIndex) = getRLS().getLandIndex(mySummoner);
        if(!result){
            return (false,0,0,0);
        }
        uint256 lsAmount = _landSummonersAmount[lIndex];
        if(sIndex >= lsAmount){
            return (false,0,0,0);
        }
        uint256 sLocation = lIndex * 100 + sIndex;
        uint256 summoner = _indexSummoner[sLocation];
        (,uint256 state) = getSummonerState(summoner);
        summonerInfo memory sInfo = _summonersInfo[summoner];
        if(state == 0){
            return(true,0,0,0);
        }
        tTime = block.timestamp - sInfo.startActiveTime;
        uint256 intervalTime = block.timestamp - sInfo.lastActiveTime;
        if(intervalTime >= _activePeriod){
            return (true,state,tTime,0);
        }
        return (true,state,tTime,(_activePeriod-intervalTime));
    }

     //The number of alive summoners on the current land
    function getSummonerAmount_MyLand(uint256 summoner)public view returns(bool,uint256){
        (bool result,uint256 lIndex) = getRLS().getLandIndex(summoner);
        if(!result){
            return (result,lIndex);
        }
        return (result,_landSummonersAmount[lIndex]);
    }
    
    function getMaxSummonersAmount_Land()public view returns(uint256){
        return _maxSummoners;
    }
    
    function getActivePeriod()public view returns(uint256){
        return _activePeriod;
    }
}