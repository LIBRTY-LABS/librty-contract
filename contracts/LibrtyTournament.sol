// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import { IERC20 } from "./interface/IERC20.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

//must be converted to ownable
contract LibrtyTournament {
    
    struct Tournament{
        string tournament_details_hash;
        address organiser;
        address token;
        uint256 amount;
        uint256 team_size;
        uint256[] prize_amount;
    }

    struct Player{
        address wallet;
        string username;
    }

    struct Team{
        Player[] players;
        uint256 split;
    }
    
    Tournament public current_tournament;
    string[] public winners;
    mapping(string => Team) public teams;

    address public LIBRTY_OPERATOR = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address public owner;
    TournamentStatus public tournament_status;

    enum TournamentStatus{ CREATED, STARTED, OVER, WINNER_LIST_SUBMITTED, WINNER_LIST_REJECTED, PRIZE_DISTRIBUTED }

    modifier onlyLibrty {
      require(msg.sender == LIBRTY_OPERATOR);
      _;
   }

   modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }

    /** Create a new tournament */
    constructor(string memory _tournament_details_hash, address token, address _organiser, uint256 amount, uint256 team_size, uint256[] memory _prize_amount) {
        current_tournament = Tournament(_tournament_details_hash, msg.sender, token, amount, team_size, _prize_amount);
        owner = _organiser;
        tournament_status = TournamentStatus.CREATED;
    }

    /** Register Captain as a team member and decide the prize split */
    function registerTeam(uint256 split, Player memory captain, string memory team_id) public onlyLibrty {
        require(tournament_status == TournamentStatus.CREATED, "Only created tournaments can do a split");
        teams[team_id].split = split;
        teams[team_id].players.push(captain);
    }

    /** Add players to the team */
    function addPlayerToTeam(Player memory player, string memory team_id) public onlyLibrty{
        teams[team_id].players.push(player);
    }

    function getTeamPlayers(string memory team_id) public view  returns (Player[] memory) {
        return teams[team_id].players;
    }

    /** Add players to the team */
    function removePlayerFromTeam(uint256 index, string memory team_id) public onlyLibrty{
        delete teams[team_id].players[index];
    }

    /** Del team */
    function deleteTeam(string memory team_id) public onlyLibrty{
        delete teams[team_id];
    }

    function startTournament() public onlyLibrty{
        require(tournament_status == TournamentStatus.CREATED, "Only created tournaments can do a split");
        tournament_status = TournamentStatus.STARTED;
    }

    function endTournament() public onlyLibrty{
        require(tournament_status == TournamentStatus.STARTED, "Only a started tournament can end");
        tournament_status = TournamentStatus.OVER;
    }

    function submitWinners(string[] memory _winners) public onlyLibrty{
        require(tournament_status == TournamentStatus.OVER || tournament_status == TournamentStatus.WINNER_LIST_REJECTED, "Only ended tournaments or reject winners can have winners");
        winners = _winners;
        tournament_status = TournamentStatus.WINNER_LIST_SUBMITTED;
    }

    function approveWinnersList() public onlyOwner{
        require(tournament_status == TournamentStatus.WINNER_LIST_SUBMITTED, "Winners are not submitted yet");
        tournament_status = TournamentStatus.PRIZE_DISTRIBUTED;

        IERC20 tokenInstance = IERC20(current_tournament.token);

        for(uint256 i = 0; i < winners.length; i++){
            Team memory winningTeam = teams[winners[i]];
            uint256 totalPrizeForTeam = current_tournament.prize_amount[i];
            uint256 captainSplit = (winningTeam.split * totalPrizeForTeam) / 100;
            tokenInstance.transfer(winningTeam.players[0].wallet, captainSplit);

            uint256 teamMemberSplit = (totalPrizeForTeam - captainSplit) / (current_tournament.team_size - 1); // removed captain from team size

            for(uint256 j = 0; j < winningTeam.players.length; j++){
                if(winningTeam.players[j].wallet != address(0)){
                    tokenInstance.transfer(winningTeam.players[j].wallet, teamMemberSplit);
                }
            }
        }
    }

    function rejectWinnersList() public onlyOwner{
        require(tournament_status == TournamentStatus.WINNER_LIST_SUBMITTED, "Winners are not submitted yet");
        tournament_status = TournamentStatus.WINNER_LIST_REJECTED;
    }
}