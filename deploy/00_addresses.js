
const uniswapAddresses = {
    factory: {
        5: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
        80001: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
        137: '0x1F98431c8aD98523631AE4a59f267346ea31F984'
    },
    router: {
        5: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
        80001: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
        137: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
    }
}

const generalAddresses = {
    WETH: {
        5: '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6',
        80001: '0x9c3c9283d3e44854697cd22d3faa240cfb032889',
        137: '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'
    }
}

const aaveAddresses = {
    v3pool: {
        5: '0x617Cf26407193E32a771264fB5e9b8f09715CdfB',
        80001: '0x0b913A76beFF3887d35073b8e5530755D60F78C7',
        137: '0x794a61358D6845594F94dc1DB02A252b5b4814aD'
    }
}

const compoundAddresses = {
    cometUSDC: {
        80001: '0xF09F0369aB0a875254fB565E52226c88f10Bc839',
        137: '0xF25212E676D1F7F89Cd72fFEe66158f541246445'
    }
}

const miscAddresses = {
    cometLens: {
        80001: '0xC49bfddbbBFB3274e9b9D2059a6344472FC91fBB',
        137: '0x47B087eBeD0d5a2Eb93034D8239a5B89d0ddD990'
    }
}

const aaveBrokerAddresses = {
    Init:{
        137: '0x2e9C883702B53c7ae3E31943D9DE4e49e43DAe71'
    },
    BrokerModuleBalancer: {
        137: '0x5494b574bEe7aa091799ECbf3DDBFEeF5da4F720'
    },
    BrokerModuleAave: {
        137: '0x476a0D24790a88185c721eE728d18465c66e9611'
    },
    Sweeper: {
        80001: '0xA83129791403c490FaA787FB0A1f03322256DE7D',
        5: '0x687cb2dF3461A8ddA00ef5f3608bA8a091c8144e',
        137: '' // deprecated
    },
    Lens: {
        80001: '0x45B1B6518ABaD20Eb911DE794Eef5F852cF08d7C',
        5: '0x709884237a3ACAeE269778C0352F2595F7a1B18c',
        137: '0x236Edc81A4e162917dA74609Eff56358E9C6aF5f'
    },
    BrokerProxy: {
        5: '0x0C233b11F886da1D5206Fa9e0d48293c23A4fDb9',
        80001: '0x529abb3a7083d00b6956372475f17B848954aC50',
        137: '0x74E95F3Ec71372756a01eB9317864e3fdde1AC53'
    },
    ConfigModule: {
        5: '0xefC2640C978cC5B695815E4B69245943d5e6dcE4',
        80001: '0x93c0774b0e269d4191efb3bdf65645a3722001a8',
        137: '0x32B31A066c8dd3F7b77283Ba1d89Ddaf6DA0a8aE'
    },
    MarginTradeDataViewerModule: {
        5: '0x636Ea7E9C4409Be6CE24A4E14bE73ef8830D83F0',
        80001: '0x8b8ADa768C1FD30d9B65da568F7098178590c307',
        137: '0xB2B6Bd4C88124D73dE0ea128c86267AB64Fd1069'
    },
    OwnershipModule: {
        5: '0x1ae0E121d80C93862e725BD2F4E92E59d6fbEb29',
        80001: '0xb490c930e83B7C9615ba745D00469882e9763817',
        137: '0xC7895BF5d8e4d049e9146ADcb750a55cD0156877'
    },
    ManagementModule: {
        5: '0x0Be9058fE2DB31E2DaCEbbE566D227D0CbfA41C8',
        80001: '0x72D580D4e59eCB3E25Dd7D1530981625640Dba15',
        137: '0x892e4a7d578Be979E5329655949fC56781eEFdb0'
    },
    MarginTraderModule: {
        5: '0xa8d1C7D918ABc6F112F89A8496962c9A6cdA52d0',
        80001: '0xE0d077f7C0d87909A939160EDae002cC9f33168f',
        137: '0xb7F9DE6e69BcbB11cBa4bd8FD0021bB808BE03d5'
    },
    MoneyMarketModule: {
        5: '0xc9ea6d976ee5280B777a0c74B986CF3B7CB31f0c',
        80001: '0xAA71A440e4ea9Bd108e06b556A16C60c610aFdf9',
        137: '' // deprecated
    },
    UniswapV3SwapCallbackModule: {
        5: '0xaDDeA1f13e5F8AE790483D14c2bb2d18C40d613b',
        80001: '0xf20e318D7D0B33631958ab233ECE11e9B7830DCd',
        137: '' // deprecated
    },
    // external
    minimalRouter: {
        5: '0x29D248785944Ea1D9e562B01466b7f107561F6B7',
        80001: '0x0cDB7da60B6Cb040e15B62a62444E16999B482d5',
        137: '0x97148db25672d106F5ADD5dE734F0eb0360290a0'
    }
}



const cometBrokerAddresses = {
    Sweeper: {
        5: '',
        80001: '0x2f15ec1A5d5ad08cbf4E64d2a6cAFE4F5ff5117B',
        137: '0x5763e18f9CfB220d1b23f89701142Fdd18C1f223'
    },
    Lens: {
        80001: '0xfD39FcbA8300AB9604D1E8FB1cC91E41a5722e34',
        5: '',
        137:'0x237620397eC1F38456Af370132E62f104f98C9A6'
    },
    BrokerProxy: {
        5: '',
        80001: '0x178E4EB141BBaEAcd56DAE120693D48d4B5f198d',
        137: '0x04555b0B7367315cdaDe1E1889FA4FCdd27b66D6'
    },
    ConfigModule: {
        5: '',
        80001: '0x93c0774b0e269d4191efb3bdf65645a3722001a8',
        137: '0xb92028D62D69a24Fc2A52Fe29CD21432Dd0504a5'
    },
    MarginTradeDataViewerModule: {
        5: '',
        80001: '0x354631d9B36563eDc9c71b0f6ED1D717925882a5',
        137: '0xa6eE39deb10A177e79bdd8233811e5E6D53F34A8'
    },
    OwnershipModule: {
        5: '',
        80001: '0x77fEa88b8661131147596330cD2208525F49Ff1A',
        137: '0xbabe787FFdf5b8630bBBBFb39582416C03f8d558'
    },
    ManagementModule: {
        5: '',
        80001: '0x8650715F2048E233adEd8f6539a22C8BC5d7C5a9',
        137: '0x12d18DfD5Bb73482E315f551bec5B8D662fDdC53'
    },
    MarginTraderModule: {
        5: '',
        80001: '0x01D8853Fd8C78B2c26097B5003184037F219F77a',
        137: '0xf655538718435f7981098821bE19fcE98477007b'
    },
    MoneyMarketModule: {
        5: '',
        80001: '0xCe9A6D29d57c409881ea284b457e97e3b7F77231',
        137: '0xF443a1F74e9eeEa693743ed23a85279fef279187'
    },
    UniswapV3SwapCallbackModule: {
        5: '',
        80001: '0xDe7194b4804a669e2B16b896fDF0b829e33f3317',
        137: '0xA96a9202DcBc31C06173f0A07102D8Ca92A6ea72'
    },
    // external
    minimalRouter: {
        5: '',
        80001: '0x0cDB7da60B6Cb040e15B62a62444E16999B482d5',
        137: '0x97148db25672d106F5ADD5dE734F0eb0360290a0'
    }
}


module.exports = {
    uniswapAddresses,
    generalAddresses,
    aaveAddresses,
    compoundAddresses,
    aaveBrokerAddresses,
    cometBrokerAddresses,
    miscAddresses
}