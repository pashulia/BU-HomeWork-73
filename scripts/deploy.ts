import { ethers } from 'hardhat';

async function main() {
    // массив адресов
    const admins = await ethers.getSigners();

    // Деплоим мултисиг
    const Multisig = await ethers.getContractFactory("Multisig");
    const multisig = await Multisig.deploy([
        admins[0].address,
        admins[1].address, 
        admins[2].address, 
        admins[3].address, 
        admins[4].address
    ]);
    await multisig.deployed();

    // Деплоим целевой контракт
    const Target = await ethers.getContractFactory("Target");
    const target = await Target.deploy(multisig.address);
    await target.deployed();

    // Собираем сообщение офф-чейн
    const nonce = await multisig._nonce();
    // собираем payload
    const iface = new ethers.utils.Interface(["function setNumber(uint256)"]);
    const payload = iface.encodeFunctionData("setNumber", [100]);
    console.log("payload:\n", payload);

    // собираем сообщение
    const message = ethers.utils.solidityPack(
        ["uint256", "address", "address", "bytes"],
        [nonce, multisig.address, target.address, payload]
    );
    console.log("message:\n", message);

    const bMessage = ethers.utils.arrayify(message);
    console.log("bMessage:\n", bMessage);

    // Подписываем
    let signatures: {
        v: number[],
        r: string[],
        s: string[]
    };
    signatures = {
        v: [],
        r: [],
        s: []
    };
    for(let i = 0; i < 3; i++) {
        const powSignature = await admins[i].signMessage(bMessage);
        const signature = ethers.utils.splitSignature(powSignature);
        signatures.v.push(signature.v);
        signatures.r.push(signature.r);
        signatures.s.push(signature.s);
    }
    console.log("signatures:\n", signatures);
    
    // Отправляем это всё в контракт
    console.log("number:\n", await target.number());
    // console.log(target);
    await multisig.verify(nonce, target.address, payload, signatures.v, signatures.r, signatures.s);
    console.log("number:\n", await target.number());
    
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
