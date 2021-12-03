// SPDX-License-Identifier: MIT 
pragma solidity >=0.7.0 <0.9.0;
import "./Election.sol";

contract Club {
    //- - - - - - - - - - - - - - -  - - - Static Values for the Contract- - - - - - - - - - - - 
    //should all be private with get functions for for esayeasier accessabiltiy during testing we leave it open
    string  public name; 
    address public clubLeader; 
    address public memberLead;  
    uint256 private votingDuration;
    uint private startTerm;
    address public immutable contractAddress;  
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
     
        
    // - - - - - - - - - - - - - - - - - - Membership Variables - - - - - - - - - - - - - - - - -     
    // storage of members 
    Member[] public allMembers;

    // mapping to get members position in member array based on his/ her address & not based on his position in storage array
    mapping (address => uint256) public memberAdrToID;  

    // membercount / note that the person that joins as e.g. 3rd according to memberCount will also be in position 3 in member array
    // when a member gets deleted, there might be issues since most functions make use of memberCount to search in array  
    uint256 public memberCount;
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


    // - - - - -  - - - - - - - - - - - - - - Application Process - - - - - -- - - - - - - - - -  
    //Buffer of maximally (31-1) wating applicants since index 0 is not included
    Member[31] private applicants; //array of waiting applicants 
    uint public applicantsCounter;
    mapping (address => bool) public applicationCheck; // mapping of check whether applicant already applied (used in requirement)
    // 11- memberlead accpet all  22- leader accetpt 33- memlead 1 44- lead 1 -> mechanism ensures that both need to accept the decision
    // impossible that only one "accepter" lets and applicant through by calling function twice 
    uint8 private aggreedOnAppl; // manges the staates of the application managing accounts
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


    //- - - - - - - - - - - - - - -  - - Election Process Variables - - - - - - - - - - - - - - - - 
    Election public currentElection; 
    address public currentElectionAdr;  // address of current election instance (needed since we can run multiple votings/elections)
    Election[] public oldElections;     // since we are able to have multiple votings/ elections, we want to store them in a sort of easy to access archive
    uint public oldElectonCount;        // counter for number of past elections
    //- - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


    //- - - - - - - - - - - - - - -  Events Functions- - - - - - - - - - - - - - - - - - - - 
    event membershipRequest(string name); 
    event newMember(string name, uint memberId );
    event memberVoted(string nameOfVoter,address addressVoter, uint candidateNumber);
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


 
    // - - - - - - - - - - - - - - - - - Basic Functions - - - - - - - - - - - - - - - - - - - - 
        function getClubLeaderName() public view returns(string memory){ 
        return allMembers[memberAdrToID[clubLeader]].name;
    } 

    // - - - - - - - - - - - - - - - - - - - - - -- - --  - - - - - - - - - - - - - - - - - - - - 


    // - - - - - - - - - - - - - - - - - - Constructor - - - - - - - - - - - - - - - - - - - - - 
    constructor(string memory _name, uint _votingDuration, address _addressLeader, address _addressMemLead ){
        votingDuration = _votingDuration; //voting in seconds for better usability 
        allMembers.push();
        name = _name; 
        clubLeader = _addressLeader; 
        memberLead = _addressMemLead; 
        contractAddress = address(this);
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


    //- - - - - - - - - - - - - - -   - - - - Structs - - - - - - - - - - - - - - - - - - - - - 
    struct Member{
        string  name;
        address memberAddress;
        //string  personalInfo;
        uint256 joiningDate;
    }
    struct Candidate{
        uint256 voteId;
        string  name;
        address addressCandidate;
        uint    numberVotes; //string  personalInfo;
    }
    
    struct smallCanditate{ //reduced form of earlier struct 
        string name;
        uint numberVotes;
    }
    //- - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

 
    // - - - - - - - - - - - - - - - - - -  Modifiers - - - - - - - - - - - - - - - - - - - - - - 
    modifier onlyMembers(){         // specifies certified members of ClubContract
        require (memberAdrToID[msg.sender] != 0 , "only Member has access rights to paticipate");
        _;
    }

    modifier manageRigthsOnly(){    // superuser privilege of 2 leader roles for applicant management
        require (msg.sender == memberLead || msg.sender==clubLeader , "only Leaders have rights to manage applicants");
        _;
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


    // - - - - - - - - - - - - - - - - - - -Application Proces - - - - - - - - - - - - - - - - - 
    function applyForMemberShip(string memory _name) public {
        require(applicantsCounter<30, "too many applicants at the moment");
        require(applicationCheck[msg.sender] == false,"you already applied for the club");
        applicantsCounter++;
        applicants[applicantsCounter] = Member(_name,msg.sender,block.timestamp);
        applicationCheck[msg.sender] = true;
        emit membershipRequest(_name);
    }

    function getApplicants() public view returns (Member[] memory ){    // shows array of all (active) applicants: from here, Leaders take / copy
        Member[] memory retApp = new Member[](applicantsCounter);       // the  adress of the last applicant to accept him/ her with function below
        for (uint256 i= 1; i<applicantsCounter+1; i++){                 // -> it's important that address is accessible since it is a mandatory 
            retApp[i-1]= applicants[i];                                 //    input in acceptLastApplicant() function
        }                                                               // [see below in denyLastApplicant()]: we only call ACTIVE (= not denied) applicants here with applicantsCounter
        return retApp;
    }

    function acceptLastApplicant(address _lastApplicantsAdr) private {  // we implemented this address parameter to make sure that the "meant to be" applicant is accepted
        require (applicants[applicantsCounter].memberAddress == _lastApplicantsAdr, 'Adress does not match!'); 
        addMember(applicants[applicantsCounter].name, applicants[applicantsCounter].memberAddress); 
        applicantsCounter--;
    }
    
    function voteAcceptAllApplicants() public manageRigthsOnly() {      // note that we only implemented this for the demo to rapidly get all persons into our contract
        require(applicantsCounter > 0, "1-no applicants for the club"); // and thereby let them participate to the vote (which then did not happen due to lack of time)
        if(msg.sender == clubLeader){
            if(11 == aggreedOnAppl ){                   // note that we implemented this four-eye principle such that the power over the applicant acceptance is distributed 
                acceptAllApplicants();                  // for the sake of simplicity, we kept it simple with 2 persons in charge, but an extension to more responsibles would
                aggreedOnAppl = 0;                      // be possible to reduce this "power concentration" & reduce potential for collusion 
            }else{
                aggreedOnAppl = 22;
            }                                           // this mechanism ensures that a leader cannot fraudlently accept an applicant by calling the function twice
        }else if(msg.sender == memberLead){
            if(22 == aggreedOnAppl  ){
                acceptAllApplicants();
                aggreedOnAppl = 0;
            }else{
                aggreedOnAppl = 11; 
            }
        }
    }
    
    function voteAcceptLastApplicant(address _lastApplicantsAdr) public manageRigthsOnly() {
        require(applicantsCounter > 0, "2-no applicants for the club");
        if(msg.sender == clubLeader){
            if (11 == aggreedOnAppl || aggreedOnAppl == 33 ){
                acceptLastApplicant(_lastApplicantsAdr);
                aggreedOnAppl = 0;
            }else{
                aggreedOnAppl = 44;
            }
        }else if(msg.sender == memberLead){
            if(22 == aggreedOnAppl || aggreedOnAppl == 44 ){
                acceptLastApplicant(_lastApplicantsAdr);
                aggreedOnAppl = 0;
            }else{
                aggreedOnAppl = 33; 
            }
        }
    }
    
    function acceptAllApplicants() private {
        for (uint256 i= applicantsCounter; applicantsCounter> 0; i--){
            addMember(applicants[i].name, applicants[i].memberAddress);
            applicantsCounter--;
        }
        
    }  

    function denyLastApplicant(address _lastApplicantsAdr) public manageRigthsOnly() {  // we did not implement the four-eye principle for denial for the sake of simplicity 
        require (applicants[applicantsCounter].memberAddress == _lastApplicantsAdr, 'Adress does not match!');
        require(applicantsCounter > 0, 'No applicants in queue!');
        applicantsCounter--;    // applicant is not deleted from applicants array, but will be overwritten by next applicant with same applicantsCounter number; we made sure that denied applicant 
    }                           // will still not show up in getApplicants() fct by letting that function only display array until the position applicant[applicantsCounter]
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

  


   


    // - - - - - - - - - - - - - - - - - - MemberMangement- - - - - - - - - - - - - - - - - - - 

    function addMember(string memory _name, address _memberAddress) private { // private since only accessed via acceptApplicants functions
        memberCount++; 
        allMembers.push(Member(_name, _memberAddress, block.timestamp ));   //store in member array
        memberAdrToID[_memberAddress] = memberCount;                        //store in member mapping 
        emit  newMember( _name, memberCount);
    }

    function getMyName() public view returns(string memory){ 
        return allMembers[memberAdrToID[msg.sender]].name; 
    }

    function getMemberId(address _addressMember) private view returns(uint ) {
        return memberAdrToID[_addressMember]; 
    }

    function getMemberNames() public view returns (string[] memory ){
        string[] memory retApp = new string[](memberCount);
        for (uint256 i= 1; i<memberCount+1; i++){
            retApp[i-1]= allMembers[i].name;
        }
        return retApp;
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


    /*
    // - - - - - - - - - - - - - - - - - - - Test Function - - - - - - - - - - - - - - - - - - -  
    // Test fuctions are only availe on a bigger block size and not for standard process 
    
    function applyForMemberShipTestCase(string memory _name, address _memberAddress) private {
        require(applicantsCounter<30, "too many applicants at the moment contact");
        require(applicationCheck[_memberAddress] == false,"address allready applied");
        applicantsCounter++;
        applicants[applicantsCounter] = Member(_name,_memberAddress,block.timestamp);
        applicationCheck[_memberAddress] = true;
    }

    function setUpDemoAdd() public { 
        //require(msg.sender ==0x1df8Ca11258cf4aCc38C0E869c199Ae39bb718c3);
        memberLead = 0xf7eBaDa39A818939f5078D1AD8714Ab6C7213Eb0;
        addMember("Lilly Fee",0x1df8Ca11258cf4aCc38C0E869c199Ae39bb718c3 ); //acc 1
        addMember("Jackson Palmer", memberLead);
        /*addMember("Hal Finney",0x9d44197549d6FBe9A695f3d866deC6DEa9d090A5); //account 3 
        addMember("Jackson Palmer",0xf7eBaDa39A818939f5078D1AD8714Ab6C7213Eb0); //account 6 

    }

    function StartDemoElecion() public { // 
        //test cases
        //applyForMemberShipTestCase("Donald Duck", 0x32c55F570507B30Ab17f5a6281B5aD1025510aAA); //Account 4
        applyForMemberShipTestCase("Sepp Hochreiter", 0x7dfa72251f71fe95F5137B559505B2F66c43A530); //Account 5
        require(currentElectionAdr == address(0));
        addMember("Hal Finney",0x9d44197549d6FBe9A695f3d866deC6DEa9d090A5); //account 3 
        addMember("Jackson Palmer",0xf7eBaDa39A818939f5078D1AD8714Ab6C7213Eb0); //account 6 
        startElection(20, 10); //in seconds for demo 
        proposeCandidate(0x9d44197549d6FBe9A695f3d866deC6DEa9d090A5);// "Hal Finney"); //account 3 
        proposeCandidate(0xf7eBaDa39A818939f5078D1AD8714Ab6C7213Eb0); //"Jackson Palmer"); //account 6
    }
    */
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    
    
    // - - - - - - - - - - - - - - - - - - -Elections Process  Functions - - - - - - - - - - - - 
    // for demo propouses _votingDuraInHours it in seconds 
   function startElection(uint8 _typElection) public onlyMembers returns(address){ //parameter voting type: elect Leader or kickMember (see in voting legend at start of Election.sol code)
        require(currentElectionAdr==address(0),"election is running");
        require(_typElection < 4 && _typElection > 0,"Invalid type");
        currentElection = new Election();               //creates new "election-instance" (= of election contract "Election.sol") -> allows multiple elections! 
        currentElectionAdr = address(currentElection); 
        currentElection.setClubAddress(contractAddress);//hereby we make sure that this contract is the only address that can interact with the current election (see "modifier clubContractOnly" in "Election.sol") 
        currentElection.setEndTime(votingDuration);   //this variable is set & cannot be picked by person starting the voting 
        currentElection.setElectionTyp(_typElection);   // sorry for the typo in typE, but correcting it now puts us at risk of messing up the whole framework & we're running out of time...
        return address(currentElection);                                           
    }

    function proposeCandidate(address _candidateAdr) public onlyMembers{
        if (currentElectionAdr != address(0) && memberAdrToID[_candidateAdr] != 0 ){ //only works if valid (=clubMember) candidate is proposed that has not already been proposed
            currentElection.addCandidate(_candidateAdr, allMembers[memberAdrToID[_candidateAdr]].name );
        }
    }

    function voteCandidate(uint _idOfCandidate) public onlyMembers(){
        currentElection.vote(_idOfCandidate);
        emit memberVoted(allMembers[memberAdrToID[msg.sender]].name, msg.sender, _idOfCandidate);
    }
    
    function endVote() public onlyMembers{
        currentElection.endVoting();
        uint8 typElection = currentElection.getElectionTyp();
        address winner = currentElection.getWinner();
        if (winner != address(57005)){  // check that we have a winner -> recall that 57005 is the DeAd address declared as winner in case of tie 
            electionResult(typElection,winner);
        }
        oldElections.push(currentElection); //put election into array of past elections -> that way we have an accessible archive of elections
        oldElectonCount++;                  
        delete currentElection; 
        delete currentElectionAdr;           // make room for next election
    }

    function electionResult(uint8 typeElection, address selectedAddress) private {  //this function materializes the consequences of a vote according to its type  
        if(typeElection == 1){
            clubLeader = selectedAddress;                                           //type 1 vote sets new clubLeader
        }else if(typeElection == 2){
            memberLead = selectedAddress;                                           //type 2 vote sets new memberLead
        }else if(typeElection == 3){                                                // type 3 vore kicks a member
            uint candidateId = currentElection.getCanIdByAddr(selectedAddress);
            uint numberVotes = currentElection.getCandidateVotesById(candidateId);
            if (2*numberVotes > memberCount ){                                      // threshold for majority is 50 %
                delete allMembers[memberAdrToID[selectedAddress]];
        }
        }
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

 
     
    // - - - - - - - - - - - - - - - - - - -Elections Show functions - - - - - - - - - - - - - - 
    function showVotes() public view returns(smallCanditate[] memory ){
        uint numberCandidates = currentElection.candidateCount();
        smallCanditate[] memory candidatesReturn =  new smallCanditate[](numberCandidates);
        for(uint256 i=1; i < numberCandidates+1; i++){
            //uint iD = currentElection.getCandidate(i).voteID
            address addr = currentElection.getCandidate(i).canAddress;
            string memory nameSmallCan = allMembers[memberAdrToID[addr]].name;
            uint numberVotes = currentElection.getCandidate(i).numberVotes;
            candidatesReturn[i-1] = (smallCanditate(nameSmallCan,numberVotes));
        }
        return candidatesReturn;        //returns only name and according votes of each candidate
    }
    /* not needed explicitly //stroage request high
    function showCandidates() public view returns(Candidate[] memory ){
        uint numberCandidates = currentElection.candidateCount();
        Candidate[] memory candidatesReturn =  new Candidate[](numberCandidates);
        for(uint256 i=1; i < numberCandidates+1; i++){
            uint iD = currentElection.getCandidate(i).voteId;
            address addr = currentElection.getCandidate(i).canAddress;
            string memory nameCan = allMembers[memberAdrToID[addr]].name;
            uint numberVotes = currentElection.getCandidate(i).numberVotes;
            candidatesReturn[i-1] = (Candidate(iD,nameCan,addr,numberVotes));
        }
        return candidatesReturn;
    }
    */
    
    
    function showElectionTime() public view returns(uint){
        return currentElection.getEndTime();
    }

    function getWinner() public view returns(address){
        return currentElection.getWinner();
    }

    function getElectionTyp() public view returns( uint8 ){
        return currentElection.getElectionTyp();
    }

    // omitted since requires too much storage
   /* function getElectionTyp() public view returns( string memory){ 
        uint8 electId =  currentElection.getElectionTyp();
        if(electId == 1){
            return "Typ 1: club leader election ";
        }else if(electId == 2){
            return "Typ 2: club meber leader election ";
        }else if(electId == 3){
            return "Typ 3: kick member address ";
        }else{
            return "Typ ? no eleciton";
        }
    }
    */
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

}
