// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DecentralizedAchievements is ERC721URIStorage, Ownable {
    uint256 public tokenCounter;
    uint256 public projectCounter;

    struct Project {
        uint256 projectId;
        address creator;
        string title;
        string description;
        uint256 reward;
        address rewardToken;
        bool useWhitelist;
        bool active;
    }

    struct Submission {
        uint256 projectId;
        address student;
        string workProof;
        bool isVerified;
        bool exists;
    }

    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => Submission)) public submissions;
    mapping(uint256 => mapping(address => bool)) public whitelistedStudents;
    mapping(uint256 => address[]) public projectApprovers;
    mapping(address => uint256[]) public creatorProjects;
    mapping(address => uint256[]) public studentSubmissions;

    event ProjectCreated(uint256 indexed projectId, address indexed creator);
    event SubmissionCreated(uint256 indexed projectId, address indexed student);
    event SubmissionVerified(uint256 indexed projectId, address indexed student);
    event RewardPaid(uint256 indexed projectId, address indexed student, uint256 amount);
    event StudentWhitelisted(uint256 indexed projectId, address indexed student);
    event ApproverAdded(uint256 indexed projectId, address indexed approver);

    constructor() ERC721("StudentAchievement", "SA") {
        tokenCounter = 0;
        projectCounter = 0;
    }

    function createProject(
        string memory _title,
        string memory _description,
        uint256 _reward,
        address _rewardToken,
        bool _useWhitelist
    ) external {
        projectCounter++;
        projects[projectCounter] = Project({
            projectId: projectCounter,
            creator: msg.sender,
            title: _title,
            description: _description,
            reward: _reward,
            rewardToken: _rewardToken,
            useWhitelist: _useWhitelist,
            active: true
        });

        creatorProjects[msg.sender].push(projectCounter);

        emit ProjectCreated(projectCounter, msg.sender);
    }

    function whitelistStudent(uint256 _projectId, address _student) external {
        require(msg.sender == projects[_projectId].creator, "Only creator can whitelist");
        whitelistedStudents[_projectId][_student] = true;
        emit StudentWhitelisted(_projectId, _student);
    }

    function addApprover(uint256 _projectId, address _approver) external {
        require(msg.sender == projects[_projectId].creator, "Only creator can add approver");
        projectApprovers[_projectId].push(_approver);
        emit ApproverAdded(_projectId, _approver);
    }

    function submitWork(uint256 _projectId, string memory _workProof) external {
        require(projects[_projectId].active, "Project not active");
        require(projects[_projectId].useWhitelist && whitelistedStudents[_projectId][msg.sender], "Student not whitelisted");

        submissions[_projectId][msg.sender] = Submission({
            projectId: _projectId,
            student: msg.sender,
            workProof: _workProof,
            isVerified: false,
            exists: true
        });

        studentSubmissions[msg.sender].push(_projectId);
        emit SubmissionCreated(_projectId, msg.sender);
    }

    function verifySubmission(uint256 _projectId, address _student, string memory _tokenURI) external {
        require(msg.sender == projects[_projectId].creator || isProjectApprover(_projectId, msg.sender), "Not authorized to verify");

        Submission storage subm = submissions[_projectId][_student];
        require(subm.exists, "Submission does not exist");
        require(!subm.isVerified, "Already verified");

        subm.isVerified = true;

        tokenCounter++;
        _mint(_student, tokenCounter);
        _setTokenURI(tokenCounter, _tokenURI);

        if (projects[_projectId].reward > 0 && projects[_projectId].rewardToken != address(0)) {
            IERC20 token = IERC20(projects[_projectId].rewardToken);
            require(token.transferFrom(projects[_projectId].creator, _student, projects[_projectId].reward), "Reward transfer failed");
            emit RewardPaid(_projectId, _student, projects[_projectId].reward);
        }

        emit SubmissionVerified(_projectId, _student);
    }

    function getCreatorProjects(address _creator) external view returns (uint256[] memory) {
        return creatorProjects[_creator];
    }

    function getStudentSubmissions(address _student) external view returns (uint256[] memory) {
        return studentSubmissions[_student];
    }

    function isStudentVerified(uint256 _projectId, address _student) external view returns (bool) {
        return submissions[_projectId][_student].isVerified;
    }

    function isProjectApprover(uint256 _projectId, address _approver) internal view returns (bool) {
        address[] memory approvers = projectApprovers[_projectId];
        for (uint256 i = 0; i < approvers.length; i++) {
            if (approvers[i] == _approver) {
                return true;
            }
        }
        return false;
    }
}
