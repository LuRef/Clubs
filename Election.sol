// SPDX-License-Identifier: MIT 
pragma solidity >=0.7.0 <0.9.0;
import "./Club.sol";

contract Election {
    // Model a Candidate
    struct Candidate {
        uint    voteId;
        string  name;
        uint256 numberVotes;
        address canAddress;
    }

    address public clubContract; 
    
    // voting endtime 
    uint votingEndTime;

    // Voting activity checker
    bool votingEnded; 
    

    // ElectionTypes Legend: 1 = leader Election;  2 = memberleader; 3 =voteKick Member
    // -> vote can be regarding "who becomes the next Clubleader/ MemberLead?" or "who should be kicked out of the club?" 
    uint8 private electionTyp; 

    // Store accounts that have voted
    mapping(address => bool) public hasVoted;

    // Fetch Candidate
    mapping(uint => Candidate) public candidates;

    //
    mapping(address => uint) private addressToCandiate;

    // Store Candidates Count
    uint public candidateCount;

    // Winner of the election
    address public winnerElection; 
    /*
    constructor() public {
    
    }
    */

    //- - - - - - - - - - - - - - - - Basic  Functions- - - - - - - - - - - - - - - - - - - - 

    function setClubAddress(address _clubAddress) public clubContractOnly(){ // not clubContract only! 
       clubContract = _clubAddress;
    }
    
    function setEndTime (uint _votingDuraHours) public clubContractOnly {    
    votingEndTime = (block.timestamp + _votingDuraHours) * 1 seconds; //in Seconds for demo purposes
    }

     modifier clubContractOnly(){
        require(msg.sender == clubContract||clubContract==address(0), "Only club members can execute this function!");   
        _;
    }

    function setElectionTyp(uint8 typ) public clubContractOnly{
        electionTyp = typ;
    }
    //- - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 



    //- - - - - - - - - - - - - - - - Basic Get Functions - - - - - - - - - - - - - - - - - - - - 

    function getEndTime() public view returns(uint){    
        uint256 time = 0;
        if (votingEndTime > block.timestamp ){  
            time  = (votingEndTime - block.timestamp); // for demo pourposes in seconds 
        }
        return time;
    }

    function getWinner() public view returns (address){
        return winnerElection ;
    }

    function getElectionTyp() public view returns(uint8) {
        return electionTyp;
    }

    function getCanIdByAddr(address candidateAddress) public view returns(uint){
        return addressToCandiate[candidateAddress];
    }
    
    function getCandidateVotesById(uint idCan) public view returns(uint){
        return candidates[idCan].numberVotes;
    } 
    //- - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 



    //- - - - - - - - - - - - - - -  - Candidate Management - - - - - - - - - - - - - - - - - - - 

    function addCandidate(address addrOfCandidate, string memory _name ) public clubContractOnly{
        require (addressToCandiate[addrOfCandidate] == 0, " Candiate has allready been proposed ! ");
        candidateCount++;
        candidates[candidateCount] = Candidate(candidateCount, _name, 0, addrOfCandidate);
        addressToCandiate[addrOfCandidate] = candidateCount;
    }

    function getCandidate(uint position) external view returns(Candidate memory){
        return candidates[position];
    }
    //- - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 



    //- - - - - - - - - - - - - - - - Election  Functions- - - - - - - - - - - - - - - - - - - - 
    function vote (uint _candidateId) public clubContractOnly {
        // require that orgina caller has not voted
        require(!hasVoted[tx.origin]);

        // require a valid candidate
        require(_candidateId > 0 && _candidateId <= candidateCount);

        // record that voter has voted
        hasVoted[tx.origin] = true;

        // update candidate vote Count
        candidates[_candidateId].numberVotes ++;
    }

    function endVoting() public clubContractOnly(){
        require(votingEndTime < block.timestamp ); 
        require(votingEnded == false );
        votingEnded == true;
        winnerElection = evalVoting();
    }

    function evalVoting() private view returns(address) { //private: can only be accessed internally -> done by endVoting fct 
        uint lead = 0;
        uint follow = 0;
        address addressLead;
        for(uint256 i=1; i < candidateCount+1; i++){      //search winner within candidates 
            if (candidates[i].numberVotes >= lead){
                follow = lead;
                lead = candidates[i].numberVotes;
                addressLead = candidates[i].canAddress;
            }
        }
        if (follow == lead){        // -> if 1st has same ammount of votes as 2nd,  the "dEaD" adress is returned 
            return address(57005);  //dead address 0x..00dEaD no winner
        }
        return addressLead; 
    } 
    //- - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

} 
