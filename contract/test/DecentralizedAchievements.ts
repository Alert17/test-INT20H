import { expect } from "chai";
import { ethers } from "hardhat";
import { DecentralizedAchievements, ERC20Mock } from "../typechain-types";

describe("DecentralizedAchievements", function () {
	let contract: DecentralizedAchievements;
	let token: ERC20Mock;
	let owner: any, student: any, verifier: any, otherStudent: any;

	before(async function () {
		[owner, student, verifier, otherStudent] = await ethers.getSigners();

		// Разворачиваем ERC20 токен для наград
		const RewardToken = await ethers.getContractFactory("ERC20Mock");
		token = await RewardToken.deploy("RewardToken", "RT", owner.address, ethers.parseEther("1000"));
		await token.deployed();

		// Разворачиваем контракт
		const DecentralizedAchievements = await ethers.getContractFactory("DecentralizedAchievements");
		contract = await DecentralizedAchievements.deploy();
		await contract.deployed();
	});

	it("Should create a new project", async function () {
		await expect(
			contract.createProject(
				"Blockchain Course",
				"Smart Contract Development",
				ethers.parseEther("10"),
				token.address,
				true
			)
		).to.emit(contract, "ProjectCreated");

		const project = await contract.projects(1);
		expect(project.creator).to.equal(owner.address);
		expect(project.title).to.equal("Blockchain Course");
	});

	it("Should whitelist a student", async function () {
		await expect(contract.whitelistStudent(1, student.address))
			.to.emit(contract, "StudentWhitelisted")
			.withArgs(1, student.address);

		const isWhitelisted = await contract.whitelistedStudents(1, student.address);
		expect(isWhitelisted).to.be.true;
	});

	it("Should add a verifier", async function () {
		await expect(contract.addApprover(1, verifier.address))
			.to.emit(contract, "ApproverAdded")
			.withArgs(1, verifier.address);
	});

	it("Should not allow non-whitelisted student to submit", async function () {
		await expect(
			contract.connect(otherStudent).submitWork(1, "ipfs://submission")
		).to.be.revertedWith("Student not whitelisted");
	});

	it("Should allow whitelisted student to submit work", async function () {
		await expect(contract.connect(student).submitWork(1, "ipfs://submission"))
			.to.emit(contract, "SubmissionCreated")
			.withArgs(1, student.address);

		const submission = await contract.submissions(1, student.address);
		expect(submission.exists).to.be.true;
		expect(submission.isVerified).to.be.false;
	});

	it("Should verify submission and mint NFT", async function () {
		await expect(contract.connect(verifier).verifySubmission(1, student.address, "ipfs://metadata"))
			.to.emit(contract, "SubmissionVerified")
			.withArgs(1, student.address);

		const submission = await contract.submissions(1, student.address);
		expect(submission.isVerified).to.be.true;

		const balance = await contract.balanceOf(student.address);
		expect(balance).to.equal(1);
	});

	it("Should transfer reward after verification", async function () {
		await token.approve(contract.address, ethers.parseEther("10"));

		const initialBalance = await token.balanceOf(student.address);

		await expect(contract.verifySubmission(1, student.address, "ipfs://metadata"))
			.to.emit(contract, "RewardPaid")
			.withArgs(1, student.address, ethers.parseEther("10"));

		const finalBalance = await token.balanceOf(student.address);
		expect(finalBalance.sub(initialBalance)).to.equal(ethers.parseEther("10"));
	});

	it("Should return correct projects for creator", async function () {
		const projects = await contract.getCreatorProjects(owner.address);
		expect(projects.length).to.equal(1);
		expect(projects[0]).to.equal(1);
	});

	it("Should return correct submissions for student", async function () {
		const [submittedProjects] = await contract.getStudentSubmissions(student.address);
		expect(submittedProjects.length).to.equal(1);
		expect(submittedProjects[0]).to.equal(1);
	});
});
