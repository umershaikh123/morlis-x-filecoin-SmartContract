// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "./soulbound.sol";

// Deployed to Polygon Mumbai 0x7C4E4Aec812B17e709b18e8FfC416c46Cd9D98dC
 

error FeesNotPaid();
error AlreadyVoted();
error NotIn_FundRaising_State();

error ZeroDonation();
error MaxAmountReached();
error callSuccessFailed();

 
contract testContract is KeeperCompatibleInterface, soulbound {

    //State variables
    uint votesRequired;
    uint votingTime;
    uint RaisingFundsTime;
    uint MinimumFundGoal;
    address Owner;

    //Mappings
    mapping(address => User) UserOf;

    mapping(bytes32 => mapping(address => bool)) hasDonated; // user donated for a specific program

    mapping(bytes32 => Program) idToProgram;
    mapping(bytes32 => mapping(address => uint256)) program_Adress_ToDonation; // user donation for a specific program
    mapping(bytes32 => mapping(address => UserVote)) program_Adress_ToVotes; // user voted for a specific program
    mapping(bytes32 => mapping(address => uint)) UserVoted; //user voted for a specific program true/false
    mapping(bytes32 => NFT) idToNFT;

    //Arrays
    bytes32[] idArray; // program id array
    Program[] Allprograms; // all programs array
    User[] userArray; // array of users

    //Enums
    enum State {
        VERIFYING_STATE,
        FAILED_STATE,
        RASING_FUNDS,
        COMPLETE_STATE
    }

    enum UserVote {
        REJECT,
        ACCEPT
    }

    //Structs
    struct User {
        address _user;
        uint256 TotalFundsDonated;
        UserVote _vote;
        bool HasVoted;
        uint256 programNo;
    }

    struct Program {
        address programOwner;
        bytes32 programId;
        string programDataCID;
        uint256 fees;
        uint256 fundGoal;
        uint256 currentFunds;
        address[] FundersList;
        address[] VotersList;
        uint256 votesRequired;
        uint256 votingTime;
        uint256 RaisingFundsTime;
        uint256 CurrentVotes;
        uint256 Rejects;
        bool fundsWithdrawn;
        bool feesRefunded;
        State _state;
    }

    struct NFT {
        string cid1; //NFT 1 who ever donates will get this
        string cid2; // NFT 2
        string cid3; // NFT 3 who ever donates at a certain amount
        uint256 value1; //  who ever donates at a value1 will get NFT2
        uint256 value2; //  who ever donates at a value2 will get NFT3
    }

    //Events

    // event for creation of user struct
    event userCreated(
        address _user,
        uint256 TotalFundsDonated,
        UserVote _vote,
        bool HasVoted,
        uint256 programNo
    );

    // event for creation of program struct
    event programCreated(
        address programOwner,
        bytes32 programId,
        string programDataCID,
        uint256 fundGoal,
        uint256 currentFunds,
        uint256 votesRequired,
        uint256 votingTime,
        uint256 RaisingFundsTime,
        uint256 CurrentVotes,
        uint256 Rejects,
        State _state
    );

    //  amount donated by user
    event donate(address userAddress, uint256 amount);

    // With draw funds raised by the organizer
    event WithdrawFundsRaisedEvent(
        address organizer,
        uint256 amount,
        bool fundsWithdrawn
    );

    // With draw fees from smart contract only owner
    event WithdrawFeesEvent(
        address _owner,
        uint256 amount,
        bool fundsWithdrawn
    );
    // With draw our fees from organizer
    event sendFeesToSmartContract(
        address SC_address,
        uint256 amount,
        bool fees_Send
    );

  

    // chainlink events
    event checkUpkeepEvent(
        bool upKeerNeeded,
        bytes performData,
        bytes32 programId
    );

    // chainlink events
    event performEvent(State _state, bytes32 programId); // track of State change of which program

    // info about struct program variables
    event Fund_Details(
        uint program_Fees,
        uint Program_CurrentFunds,
        State Program_State,
        uint Program_FundsRemaining
    );

    // info about struct program variables
    event Voting_Detail(
        uint votesRequired,
        uint TotalVotes,
        uint CurrentVotes,
        uint Rejects,
        uint votedForthisevent
    );

    // stored each program nft information in a struct
    event nft(
        string cid1,
        string cid2,
        string cid3,
        uint256 value1,
        uint256 value2
    );

    modifier _onlyOwner() {
        require(msg.sender == Owner);
        _;
    }

    constructor() public {
        MinimumFundGoal = 0.5 ether;
    }

    function CreateNewProgram(uint256 fundGoal, string calldata programDataCID)
        external
        payable
    {
        bytes32 programId = keccak256(
            abi.encodePacked(msg.sender, address(this), fundGoal)
        );

        State _state;

        uint fees = (fundGoal * 5) / 1000;

        if (msg.value < fees) {
            revert FeesNotPaid();
        }

        votesRequired = 3;
        votingTime = 3 minutes;
        RaisingFundsTime = 3 minutes;

        address[] memory FundersList;
        address[] memory VotersList;

        idToProgram[programId] = Program(
            msg.sender,
            programId,
            programDataCID,
            fees,
            fundGoal,
            0 ether,
            FundersList,
            VotersList,
            votesRequired,
            votingTime,
            RaisingFundsTime,
            0,
            0,
            false,
            false,
            _state = State.VERIFYING_STATE
        );

        Program memory _program = idToProgram[programId];

        Allprograms.push(_program);
        idArray.push(programId);

        emit programCreated(
            msg.sender,
            _program.programId,
            _program.programDataCID,
            _program.fundGoal,
            0,
            _program.votesRequired,
            _program.votingTime,
            _program.RaisingFundsTime,
            0,
            0,
            _program._state
        );
    }

    //When accept button is clicked in voting section

    function Accept(bytes32 programId) external {
        Program storage myProgram = idToProgram[programId];

        if (UserVoted[programId][msg.sender] == 1) {
            revert AlreadyVoted();
        }

        UserVote _vote = UserVote.ACCEPT;

        UserOf[msg.sender] = User(msg.sender, 0, _vote, true, 0);
        User storage _user = UserOf[msg.sender];

        myProgram.VotersList.push(msg.sender);
        myProgram.CurrentVotes += 1;
        program_Adress_ToVotes[programId][msg.sender] = _vote;
        userArray.push(User(msg.sender, 0, _vote, true, 0));
        _user.programNo += 1;
        UserVoted[programId][msg.sender] = 1;

        emit userCreated(msg.sender, 0, _vote, true, _user.programNo);
    }

    //When Reject button is clicked in voting section
    function Reject(bytes32 programId) external {
        Program storage myProgram = idToProgram[programId];

        if (UserVoted[programId][msg.sender] == 1) {
            revert AlreadyVoted();
        }

        UserVote _vote = UserVote.REJECT;

        UserOf[msg.sender] = User(msg.sender, 0, _vote, true, 0);
        User storage _user = UserOf[msg.sender];
        myProgram.VotersList.push(msg.sender);
        myProgram.Rejects += 1;
        program_Adress_ToVotes[programId][msg.sender] = _vote;
        userArray.push(User(msg.sender, 0, _vote, true, 0));
        UserVoted[programId][msg.sender] = 1; // user has voted for this particular program
        _user.programNo += 1;

        emit userCreated(msg.sender, 0, _vote, true, _user.programNo);
    }

    //Donate button pressed
    function Donate(bytes32 programId) external payable {
        Program storage myProgram = idToProgram[programId];

        require(myProgram._state == State.RASING_FUNDS, "w_state");

        if (msg.value < 0) {
            revert ZeroDonation();
        }

        if (myProgram.fundGoal < myProgram.currentFunds + msg.value) {
            revert MaxAmountReached();
        }

        if (hasDonated[programId][msg.sender] == false) {
            myProgram.FundersList.push(msg.sender);
        }

        myProgram.currentFunds += msg.value;
        hasDonated[programId][msg.sender] = true;

        User storage user = UserOf[msg.sender];
        user.TotalFundsDonated += msg.value;

        program_Adress_ToDonation[programId][msg.sender] += msg.value;

        emit donate(msg.sender, msg.value);
    }

    // Oraganizer withdrawing funds when the program is in COMPLETED STATE
    function WithdrawFundsRaised(bytes32 programId) external {
        Program storage myProgram = idToProgram[programId];
        require(msg.sender == myProgram.programOwner);
        require(myProgram._state == State.COMPLETE_STATE);
        require(myProgram.fundsWithdrawn == false);
        require(myProgram.currentFunds == myProgram.fundGoal);

        (bool callSuccess, ) = payable(msg.sender).call{
            value: myProgram.fundGoal
        }("");

        // require(callSuccess, "Program funds Withdrawn failed");

        if (callSuccess == false) {
            revert callSuccessFailed();
        }

        myProgram.fundsWithdrawn == true;
        emit WithdrawFundsRaisedEvent(
            myProgram.programOwner,
            myProgram.fundGoal,
            myProgram.fundsWithdrawn
        );
    }

    // Refund  organizer Fees , funds if failed
    function RefundFeesFunction(bytes32 programId) internal {
        Program storage myProgram = idToProgram[programId];
        require(myProgram._state == State.FAILED_STATE);
        require(myProgram.feesRefunded == false);

        (bool callSuccess, ) = payable(myProgram.programOwner).call{
            value: myProgram.fees
        }("");

       
        if (callSuccess == false) {
            revert callSuccessFailed();
        }

        myProgram.feesRefunded = true;

        
    }

    function RefundFundsFunction(bytes32 programId) internal {
        Program storage myProgram = idToProgram[programId];
        require(myProgram._state == State.FAILED_STATE);

        if (myProgram.RaisingFundsTime == 0) {
            (bool callSuccess, ) = payable(myProgram.programOwner).call{
                value: myProgram.fees
            }("");
            

            if (callSuccess == false) {
                revert callSuccessFailed();
            }

            for (uint256 i = 0; i < myProgram.FundersList.length; i++) {
                (bool callSuccess2, ) = payable(myProgram.FundersList[i]).call{
                    value: program_Adress_ToDonation[programId][
                        myProgram.FundersList[i]
                    ]
                }("");

             
                if (callSuccess2 == false) {
                    revert callSuccessFailed();
                }
 
            }
        }
    }

    function WithdrawFees() external payable _onlyOwner {
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");

        
        if (callSuccess == false) {
            revert callSuccessFailed();
        }

        emit WithdrawFeesEvent(msg.sender, address(this).balance, callSuccess);
    }

    function checkUpkeep(
        bytes calldata /*checkData */
    ) external override returns (bool upkeepNeeded, bytes memory performData) {
        uint256 TotalVotes;

        for (uint i = 0; i < idArray.length; i++) {
            Program memory myProgram = idToProgram[idArray[i]];
            TotalVotes = myProgram.CurrentVotes + myProgram.Rejects;
            upkeepNeeded =
                ((myProgram.votingTime == 0) &&
                    (myProgram.Rejects > myProgram.CurrentVotes &&
                        myProgram.votesRequired <= TotalVotes)) ||
                (myProgram.CurrentVotes > myProgram.Rejects &&
                    myProgram.votesRequired <= TotalVotes) ||
                (myProgram.RaisingFundsTime == 0) ||
                (myProgram.currentFunds >= myProgram.fundGoal) ||
                (myProgram._state == State.COMPLETE_STATE);

            for (uint256 j = 0; j < myProgram.FundersList.length; j++) {
                upkeepNeeded = (hasDonated[idArray[i]][
                    myProgram.FundersList[j]
                ] = true);
            }

            performData = abi.encode(idArray[i]);
            emit checkUpkeepEvent(upkeepNeeded, performData, idArray[i]);
            return (upkeepNeeded, performData);
        }

        return (false, "");
    }


    // Check if state perform upkeep changed something
    event cond(bool performedRan);

 
    function storeNFTURI(
        string memory cid1,
        string memory cid2,
        string memory cid3,
        uint256 value1,
        uint256 value2,
        bytes32 programId
    ) public {
        idToNFT[programId] = NFT(cid1, cid2, cid3, value1, value2);

        emit nft(cid1, cid2, cid3, value1, value2);
    }

    function performUpkeep(bytes calldata performData) external override {
        bytes32 programId = abi.decode(performData, (bytes32));

        Program storage myProgram = idToProgram[programId];
        NFT storage _nft = idToNFT[programId];

        uint256 TotalVotes = myProgram.CurrentVotes + myProgram.Rejects;

        if (
            (myProgram.votingTime == 0 &&
                myProgram._state == State.VERIFYING_STATE) ||
            (myProgram.Rejects > myProgram.CurrentVotes &&
                myProgram.votesRequired <= TotalVotes)
        ) {
            myProgram._state = State.FAILED_STATE;
            RefundFeesFunction(programId);
            emit performEvent(myProgram._state, programId);
            emit cond(true);
        } else if (
            myProgram.CurrentVotes > myProgram.Rejects &&
            myProgram.votesRequired <= TotalVotes &&
            myProgram._state == State.VERIFYING_STATE
        ) {
            myProgram._state = State.RASING_FUNDS;

            emit performEvent(myProgram._state, programId);
            emit cond(true);
        } else if (
            myProgram.RaisingFundsTime == 0 &&
            myProgram._state == State.RASING_FUNDS
        ) {
            myProgram._state = State.FAILED_STATE;
            RefundFeesFunction(programId);
            RefundFundsFunction(programId);
            emit performEvent(myProgram._state, programId);
            emit cond(true);
        } else if (
            myProgram.currentFunds >= myProgram.fundGoal &&
            myProgram._state == State.RASING_FUNDS &&
            myProgram.RaisingFundsTime != 0
        ) {
            myProgram._state = State.COMPLETE_STATE;
            emit performEvent(myProgram._state, programId);
            emit cond(true);
        } else if (myProgram._state == State.COMPLETE_STATE) {
            for (uint256 j = 0; j < myProgram.FundersList.length; j++) {
                uint donation = program_Adress_ToDonation[programId][
                    myProgram.FundersList[j]
                ];
                if (hasDonated[programId][myProgram.FundersList[j]] = true) {
                    safeMint(myProgram.FundersList[j], _nft.cid1);

                    if (donation >= _nft.value1) {
                        safeMint(myProgram.FundersList[j], _nft.cid2);
                    }

                    if (donation >= _nft.value2) {
                        safeMint(myProgram.FundersList[j], _nft.cid3);
                    }
                    emit cond(true);
                }
            }
        } else {
            emit cond(false);
        }
    }

    //Getters functions

    function getIdArray() public view returns (bytes32[] memory) {
        return idArray;
    }

    function getId(uint index) public view returns (bytes32) {
        return idArray[index];
    }

    function getProgram_Voting_Detail(bytes32 programId)
        public
        returns (
            uint,
            uint,
            uint,
            uint,
            uint
        )
    {
        Program memory myProgram = idToProgram[programId];

        uint TotalVotes = myProgram.CurrentVotes + myProgram.Rejects;
        emit Voting_Detail(
            myProgram.votesRequired,
            TotalVotes,
            myProgram.CurrentVotes,
            myProgram.Rejects,
            UserVoted[programId][msg.sender]
        );
        return (
            myProgram.votesRequired,
            TotalVotes,
            myProgram.CurrentVotes,
            myProgram.Rejects,
            UserVoted[programId][msg.sender]
        );
    }

    // function getAllUserVotes(bytes32 programId)
    //     external
    //     view
    //     returns (UserVote)
    // {
    //     return program_Adress_ToVotes[programId][msg.sender];
    // }

    function getAllPrograms()
        public
        view
        _onlyOwner
        returns (Program[] memory)
    {
        return Allprograms;
    }

    // function getPrograms(uint index)
    //     public
    //     view
    //     _onlyOwner
    //     returns (Program memory)
    // {
    //     return Allprograms[index];
    // }

    function getProgram_Fund_Details(bytes32 programId)
        public
        returns (
            uint,
            uint,
            State,
            uint
        )
    {
        Program memory myProgram = idToProgram[programId];
        uint remaining = myProgram.fundGoal - myProgram.currentFunds;
        emit Fund_Details(
            myProgram.fees,
            myProgram.fundGoal,
            myProgram._state,
            remaining
        );
        return (
            myProgram.fees,
            myProgram.currentFunds,
            myProgram._state,
            remaining
        );
    }

    // function getFundGoal(bytes32 programId) public view returns (uint256) {
    //     Program memory myProgram = idToProgram[programId];
    //     return myProgram.fundGoal;
    // }

    function getVotersList(bytes32 programId)
        public
        view
        returns (address[] memory)
    {
        Program memory myProgram = idToProgram[programId];
        return myProgram.VotersList;
    }

    function getfundersList(bytes32 programId)
        public
        view
        returns (address[] memory)
    {
        Program memory myProgram = idToProgram[programId];
        return myProgram.FundersList;
    }

    // function getAllUserDonations(bytes32 programId)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     return program_Adress_ToDonation[programId][msg.sender];
    // }

    function ChangeMinFundGoal(uint _amount) public _onlyOwner {
        MinimumFundGoal = _amount;
    }
}
