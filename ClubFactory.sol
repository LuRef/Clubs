// SPDX-License-Identifier: MIT 
pragma solidity >=0.7.0 <0.9.0;
import "./Club.sol";

/*
      * ClubFactory creates Club instancesa nd stores them 
      * not on normal blocksize contect for extended blocksize 
*/
contract ClubFactory {
    address public lastClubAddress;
    Club[] public clubs; //array providing overview of constructed dlubc
    function createClub(string memory _name, uint _votingDuration, address _addressLeader, address _addressMemLead) public {
        Club newClub = new Club(_name, _votingDuration, _addressLeader, _addressMemLead );
        lastClubAddress = address(newClub);
        clubs.push(newClub);
    }

}

