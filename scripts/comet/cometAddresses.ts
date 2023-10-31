

const tokensMumbai: { [key: string]: string } = {
    DAI: '0x4DAFE12E1293D889221B1980672FE260Ac9dDd28',
    USDC: '0xDB3cB4f2688daAB3BFf59C24cC42D4B6285828e9',
    WETH: '0xE1e67212B1A4BF629Bdf828e08A3745307537ccE',
    WBTC: '0x4B5A0F4E00bC0d6F16A593Cae27338972614E713',
    WMATIC: '0xfec23a9E1DBA805ADCF55E0338Bf5E03488FC7Fb',
    MATICX: '0xfa68fb4628dff1028cfec22b4162fccd0d45efb6'

}

export const cometAddress = {
    80001: {
        USDC: '0xF09F0369aB0a875254fB565E52226c88f10Bc839'
    },
    137: {
        USDC: '0xF25212E676D1F7F89Cd72fFEe66158f541246445'
    }

}


const tokensGoerli: { [key: string]: string } = {
    // AAVE: '0xE205181Eb3D7415f15377F79aA7769F846cE56DD',
    // DAI: '0xD77b79BE3e85351fF0cbe78f1B58cf8d1064047C',
    // USDC: '0x69305b943C6F55743b2Ece5c0b20507300a39FC3',
    // WETH: '0x84ced17d95F3EC7230bAf4a369F1e624Ae60090d',
    // LINK: '0x2166903C38B4883B855eA2C77A02430a27Cdfede',
    // GHO: '0xcbE9771eD31e761b744D3cB9eF78A1f32DD99211'
}


const tokensPolygon: { [key: string]: string } = {
    USDC: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
    WETH: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
    WBTC: '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6',
    WMATIC: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
    STMATIC: '0x3a58a54c066fdc0f2d55fc9c89f0415c92ebf3c4',
    MATICX: '0xfa68fb4628dff1028cfec22b4162fccd0d45efb6',
}



export const compoundTokens: { [chainId: number]: { [key: string]: string } } = {
    5: tokensGoerli,
    80001: tokensMumbai,
    137: tokensPolygon
}
