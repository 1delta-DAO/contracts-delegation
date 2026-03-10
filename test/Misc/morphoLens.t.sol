// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {MorphoLens} from "../../contracts/external-protocols/misc/MorphoLens.sol";

/**
 * Exotic market ids for lista
 */
contract IdProvider {
    bytes32[] internal marketIdsStorage;

    constructor() {
        marketIdsStorage.push(0xdee403936c6f4c64095e68301c0b5ea2d49fa36ed204b61d504f55b280079a36);
        marketIdsStorage.push(0x9ad4bc09ddbf5c9a973ebaa01ff611881d2e6f0950cb191e1d1b4203943a6858);
        marketIdsStorage.push(0xc44acfc487b8fd576fd2ca4625f672ccd7b41b87834c6358c7f7f0e6481fbf10);
        marketIdsStorage.push(0x3cd3c9f4c51934fba7c8607c0c6a17aaecc1bb13091d372b533aa2089d79e5f2);
        marketIdsStorage.push(0x997cf874bb5fddc1d4fdf29c0a2d4b3d0780cba48fa1d06c559611c064a476b0);
        marketIdsStorage.push(0x7fe248d8459a88e50e8582c71219edbce1079437e58190aeab41ac503694f0a5);
        marketIdsStorage.push(0x60415e312f17baaeeb4c00d3fe8bdb24856b18e63fff372a8cc351af00d40082);
        marketIdsStorage.push(0xe3a95b74409bedf242760e995d61062864a28c7cea15d96911caca6060933324);
        marketIdsStorage.push(0x7cee0859484ac4479e06874537d836f18a4f32a408d6df0a2d0104b2a10db85c);
        marketIdsStorage.push(0x2a679d85b2c64c6e72dc6d98c63f4ddbdae44dda0be4f93a87391192023f733b);
        marketIdsStorage.push(0x078d06a2c852f94c05f291b7288e5120d104ef0e9aa27632df4cb0b6f03cefdc);
        marketIdsStorage.push(0xab3827ad876b82fb5af9af8bf3f0bbc8a01e8602389053a71513db72c5f129f7);
        marketIdsStorage.push(0x93891e0b87829c0c80d1c78e8b5edba67795ed64358f12ad9dfe7f29694142c4);
        marketIdsStorage.push(0x3b4a64c5d230773d31440dee7f98245784b362130baca089b9ea81a777628746);
        marketIdsStorage.push(0x7a72ecec7d2155f0aaa0fc777eed426eae1053defd94ebf215c91caeb53386d2);
        marketIdsStorage.push(0x3d7130826eda2be000c2320b5a43d4fe031bd91d3368f00e4025b873395cc7cc);
        marketIdsStorage.push(0x855f3e05048664c2332b8e2d8eba4f860fb130ff5b51ded4b7b8cac8784d5ec4);
        marketIdsStorage.push(0xabee0fa997d37986440bd4c8a6dd4ee4ffe09b7c8689f65fe0e4ff611c7a0413);
        marketIdsStorage.push(0xf9b4445df13dec8864cd7a0bfbb3c2cb46c06e2ebcdac697e0f9e8782c1ed7e1);
        marketIdsStorage.push(0x41138a5d7ac6f084921fbcce32c9dd1fc2a67867f15efa9dbe9e4c15e914acfa);
        marketIdsStorage.push(0xfef2a9fbeae30c0a8278877fefba5d750e10c3ef5de09662eb174a1fe5fd96c6);
        marketIdsStorage.push(0x211cab18d1ecd7428bdec32ea3b379af98553b5b718b5a44979594643dc095a2);
        marketIdsStorage.push(0x9ae45397a8063220d4cdb41ad9268d4c173dd18ca778171e9dee0644dfbe4cbd);
        marketIdsStorage.push(0x3b8a877d18d83b71d647225012d87457d750eb5da4f977d0b0718de0b0657408);
        marketIdsStorage.push(0xae82d976f5470fa4fc7c32b4f01069351874516946de7352cb783381a0e94d14);
        marketIdsStorage.push(0x094e97b229d39cda28aa54e7e80e1d6ccb2328defd4678adfbf1cd0909573d20);
        marketIdsStorage.push(0xc386f1b385b22a0fd98b9a27ff84a724a0bbbf3dcf7e0eb5a84150ac123037c5);
        marketIdsStorage.push(0x23d162a36b0112edc6e6f71e0870e45ff1220ea34a8f15e49bdcaac88704360b);
        marketIdsStorage.push(0x1ba331693829914e685b153bbb6a2ba7ce13123b56cf27f242d4b6fee446c05d);
        marketIdsStorage.push(0xed7856d2ed4fb7f2e8e989065024bdd16af4f33390be824430ce723846531c9a);
        marketIdsStorage.push(0xaff3852ab9f7562b1894384366b976079efc12aeb872387c3b8d7e629d01961c);
        marketIdsStorage.push(0x4bf17995291c8845077d283ac89943f50614a52455537392a70b98d2ddc035a9);
        marketIdsStorage.push(0x0ce1192c618a82e6984f6dbb3dd6e390dfccdab98e50c0be3a617b3d7d6e9c69);
        marketIdsStorage.push(0xd973dcab7fdd6d27d8c7387423814b56dba95ade38a0048961702a524ebf3f8f);
        marketIdsStorage.push(0x20c99bccf90e1489ca5074dfb9ffb53e1928b4a6368f557dd5ee2b7d4319dbc1);
        marketIdsStorage.push(0x0bcde35135ad50babac58ae234faeebeafbda3119a1b2dfa6ace71e4b7a68982);
        marketIdsStorage.push(0x7bee99374d6200dc87b5e34b230f6a991f7ea2137d232567dc0c88ae059909a7);
        marketIdsStorage.push(0x9e40dd79c148c3ee9d5ec32f547f4a2aa6643b292a6f212289bc975461d830fc);
        marketIdsStorage.push(0x87a4f29188699279b0868c757e00861e590d274063629c6c879d83ba362c0eed);
        marketIdsStorage.push(0x054b62cfa2c7794e2aed0b79e0b873f1426ebe9cffab2afeafe34d3c84adf49a);
        marketIdsStorage.push(0x04b1a2ba0d6bc86117ddd6f9a959c42a05f87db164de10094b63d26752f1fe92);
        marketIdsStorage.push(0xc86061ee3f8e87c888e5f1866f9cf32905b841a54d55326fd773da8b7f37bb05);
        marketIdsStorage.push(0x2cbed3b86d3cad6fb2d7163287f28561d6f6c90f58513746ef34962c83e80451);
        marketIdsStorage.push(0xb194738b63e6bbbc3e62fedca3f1b93a6849829bae11dc885d33ea935bfa6a30);
        marketIdsStorage.push(0xf97712f8a9a0d5265241a01963110528d9c3b1d8ef613adfda969ad5682f2cc0);
        marketIdsStorage.push(0x896579c1926092cc9daee46137dd94ee10a7c56331cf0521bdc5af93aca85d17);
        marketIdsStorage.push(0x17230b8678f7efac75e99f4d9db9b2e5e74aabc1f34156b574b676a8e4e8e6f1);
        marketIdsStorage.push(0xa8c1b55934c79a97711dfda3ccd6dfa5b40566f256a075a490cd0829d981bf0b);
        marketIdsStorage.push(0xc87d09294447fd2f9f4d7088790ed1a4ceaf0eaecc5e8cb03ce5849e924c4725);
        marketIdsStorage.push(0x9ee44a1fa21d54fc5b248b73b49b7036b7461d06fabb9ec2bc6cd3d793114383);
        marketIdsStorage.push(0x8edffcd3d80ef3e77f3469fca7a9514280716ffb0cc0fc8b72ec39d7d7ed9788);
    }

    function getIds() external view returns (bytes32[] memory ids) {
        ids = marketIdsStorage;
    }
}

contract MorphoLensTest is Test {
    MorphoLens public morphoLens;
    address public immutable moolah = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
    address public immutable user = 0x07CF7b53F524783858F2739737730D513643F909;
    bytes32 public immutable id1 = 0x2292a4820cdf330b88ba079671484d228db4a07957db9bc24e3f1c0b42c44b84;
    bytes32 public immutable id2 = 0xa6a01504ccb6a0e3832e1fae31cc4f606a7c38cd76071f27befd013b8e46e78e;
    bytes32 public immutable id3 = 0x93e0995138222571035a6deadd617efad2f2400d69067a0d1fc74b179657046a;
    bytes32 public immutable id4 = 0xf3a85dfdf8c44398c49401aa8f4dc3be20bff806b9da2e902d3b379790a312c6;
    bytes32 public immutable id5 = 0x2e865d41371fb021130dc872741c70564d0f5ea4856ff1542163a8b59b0b524d;

    function setUp() public {
        vm.createSelectFork("https://public-bsc-mainnet.fastnode.io");
        morphoLens = new MorphoLens();
    }

    function test_getUserDataCompact_base() public view {
        bytes32[] memory marketIds = new bytes32[](5);
        marketIds[0] = id1;
        marketIds[1] = id2;
        marketIds[2] = id3;
        marketIds[3] = id4;
        marketIds[4] = id5;
        morphoLens.getUserDataCompact(marketIds, user, moolah);

        bytes memory data = morphoLens.getListaMarketDataCompact(moolah, marketIds);
        vm.assertEq(data.length, 397 * marketIds.length);
    }

    function test_getUserDataCompact_exotic() public {
        IdProvider p = new IdProvider();
        bytes32[] memory marketIds = p.getIds();

        morphoLens.getUserDataCompact(marketIds, user, moolah);

        bytes memory data = morphoLens.getListaMarketDataCompact(moolah, marketIds);
        vm.assertEq(data.length, 397 * marketIds.length);
    }

    function test_rateCap_and_rateFloor() public view {
        // market 0x3cd3c9...5f2 has known rateCap and rateFloor set via IRM 0xfe7dae...7c
        bytes32 marketId = 0x3cd3c9f4c51934fba7c8607c0c6a17aaecc1bb13091d372b533aa2089d79e5f2;
        address irm = 0xFe7dAe87Ebb11a7BEB9F534BB23267992d9cDe7c;

        bytes32[] memory marketIds = new bytes32[](1);
        marketIds[0] = marketId;

        bytes memory data = morphoLens.getListaMarketDataCompact(moolah, marketIds);
        vm.assertEq(data.length, 397);

        // rateCap is uint128 at offset 304, rateFloor is uint128 at offset 320
        uint128 rateCap;
        uint128 rateFloor;
        assembly {
            rateCap := shr(128, mload(add(add(data, 32), 304)))
            rateFloor := shr(128, mload(add(add(data, 32), 320)))
        }

        // compare against direct IRM calls
        (bool s1, bytes memory r1) = irm.staticcall(abi.encodeWithSignature("rateCap(bytes32)", marketId));
        (bool s2, bytes memory r2) = irm.staticcall(abi.encodeWithSignature("rateFloor(bytes32)", marketId));
        require(s1 && s2, "IRM calls failed");

        uint256 expectedCap = abi.decode(r1, (uint256));
        uint256 expectedFloor = abi.decode(r2, (uint256));

        vm.assertEq(uint256(rateCap), expectedCap);
        vm.assertEq(uint256(rateFloor), expectedFloor);
        // sanity: both should be non-zero for this market
        vm.assertGt(uint256(rateCap), 0);
        vm.assertGt(uint256(rateFloor), 0);
    }
}
