// Contract Imports
const FundForwarder = artifacts.require('../contracts/FundForwarder.sol')
const GivethCampaign = artifacts.require('../contracts/GivethCampaign.sol')
const Token = artifacts.require("../contracts/MiniMeToken.sol")
const TokenFactory = artifacts.require("MiniMeTokenFactory")
const Vault = artifacts.require("../contracts/Vault.sol")

// Helper Imports
const filterCoverageTopics = require("./helpers/filterCoverageTopics.js")
const days = require("./helpers/days.js")
const hours = require("./helpers/hours.js")
const wei = require("./helpers/wei.js")
const assertJump = require("./helpers/assertJump.js")
const timeTravel = require('./helpers/timeTravel.js')

contract("Fund Forwarder", (accounts) => {
    const {
        0: owner,
        1: escapeHatchCaller,
        2: escapeHatchDestination,
        3: securityGuard,
        4: guest,
        5: spender
    } = accounts
    let initialVaultBalance
    let forwarder
    let campaign
    let now
    let tokenFactory
    let token
    let benfic
    let Campaign
     beforeEach( async () => {
        now = (await web3.eth.getBlock("latest")).timestamp
        tokenFactory = await TokenFactory.new( //  
        )

        token = await Token.new(
            tokenFactory.address,
            0,
            0,
            "Minime Test Token",// name
            18,// decimals
            "MMT", // symbol
            true // transfers enabled
        )
        vault = await Vault.new(
            0,
            escapeHatchCaller,
            escapeHatchDestination,
            86400, // absoluteMinTimeLock
            86400 * 2, // timeLock
            securityGuard,
            86400 * 21, // maxSecurityGuardDelay
        )
        campaign = await GivethCampaign.new(
            now,
            now + days(365),
            web3.toWei(10000), // 10000 ether for beta
            vault.address, //vaultAddress
            token.address 
        )
        let T = Token.at(token.address)
        await T.changeController(campaign.address)

        forwarder = await FundForwarder.new(
            // deploy a GivethCampaign here
            campaign.address,
            escapeHatchCaller,
            escapeHatchDestination
        )
        benfic = await forwarder.beneficiary()
        Campaign = GivethCampaign.at(benfic)
        // Advance the campain two days
        await timeTravel(days(2))
        now = web3.eth.getBlock("latest").timestamp
    })

    it('Should initialize correctly', async () => {        
        // Make sure the token campaign is the beneficiary of the forwarding contract
        assert.equal(benfic, campaign.address)
        // Ensure all relevent balances are empty
        assert.equal(await Campaign.tokenContract(), token.address)
        assert.equal(web3.eth.getBalance(vault.address).toNumber(), 0)
        let tokenBalance = await token.balanceOf(owner)
        assert.equal(tokenBalance.toNumber(), 0)
        // Verify the campaign funding times relative to the current time        
        assert.isTrue(
            now > (await Campaign.startFundingTime.call()).toNumber()
        )        
        assert.isTrue(
            now < (await Campaign.endFundingTime.call()).toNumber()
        )
        // Ensure the campaign has a token attached to it        
        assert.isTrue(
            await Campaign.tokenContract.call() !== 0
        )
        // Ensure maximum funding has not been reached        
        assert.isTrue(
            await Campaign.totalCollected.call() < await Campaign.maximumFunding.call()
        )        
    })

    it('Should forward funds to the vault', async () => {
        let sendData = await forwarder.send(10000)
        let campaignVault = await Campaign.vaultAddress()
        assert.equal((await Campaign.totalCollected.call()).toNumber(), 10000)        
        assert.equal(web3.eth.getBalance(campaignVault).toNumber(), 10000)
    })

    it('Should not leave funds in the forwarder contract', async () => {
        let sendData = await forwarder.send(10000)
        assert.equal((web3.eth.getBalance(forwarder.address)).toNumber(), 0)
    })

    it('Should generate an event on sending funds', async () => {
        let sendData = await forwarder.send(10000)
        const {event, args} = sendData.logs[0]
        assert.equal(event, "FundsSent")
        assert.equal(args.sender, owner)
        assert.equal(args.amount.toNumber(), 10000)
    })

    it('Should create MMT for owner after sending funds to fund forwarder', async () => {
        let sendData = await forwarder.send(10000)
        let tokenBalance = await token.balanceOf(owner)
        assert.equal(tokenBalance.toNumber(), 10000)
    })

    it('Should allow non-ether funds to be escaped', async () => {
        // Send funds to the fund forwarder
        let sendData = await forwarder.send(10000)
        token.transfer(forwarder.address, 10000)
        let tokenBalance = await token.balanceOf(forwarder.address)
        assert.equal(tokenBalance.toNumber(), 10000)
        forwarder.claimTokens(token.address)
        tokenBalance = await token.balanceOf(forwarder.address)
        assert.equal(tokenBalance.toNumber(), 0)
        let hatchBalance = await token.balanceOf(escapeHatchDestination)
        assert.equal(hatchBalance.toNumber(), 10000)                   
    })

})