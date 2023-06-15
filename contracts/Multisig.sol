//SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

contract MultisigOffChain {
    // словарь админов
    mapping(address => bool) admins;
    // кол-во админов
    uint256 adminsCount;
    uint256 public nonce;

    event Verify(bool success);

    constructor(address[] memory _admins) {
        adminsCount = _admins.length;
        for(uint256 i = 0; i < _admins.length; i++) {
            admins[_admins[i]] = true;
        }
    }

    function verify(
        uint256 _nonce,
        address target,
        bytes calldata payload,
        uint8[] calldata v,
        bytes32[] calldata r,
        bytes32[] calldata s
    ) public payable {
        // проверка nonce
        require(_nonce == nonce, "Bad nonce");
        // проверяем размеры массивов
        require(v.length == r.length && r.length == s.length, "Bad arrays length");
        // получаем хэш сообщения из исходных данных
        bytes32 messagehash = getMessageHash(nonce, target, payload);
        nonce++;
        // получаем кол-во правильных подписей
        uint256 signerCount = _verify(messagehash, v, r, s);
        // проверяем сколько админов подписало сообщение
        require (signerCount > adminsCount / 2, "Not enough signatures");
        // совершаем низкоуровневый вызов
        bool success = lowLevelCall(target, payload, msg.value);
        
        emit Verify(success);
    }

    // это функция для сборки хэша сощбщения из исходных данных
    function getMessageHash(
        uint256 _nonce,
        address target,
        bytes calldata payload
    ) internal view returns(bytes32) {
        bytes memory message = abi.encodePacked(_nonce, address(this), target, payload);
        bytes memory prefix = "\x19Ethereum Signed Messge:\n";
        bytes memory digest = abi.encodePacked(prefix, toBytes(message.length), message);
        return keccak256(digest);
    }

    function toBytes(uint256 number) internal pure returns(bytes memory) {
        uint256 temp = number;
        uint256 digits = 0;
        do {
            temp /= 10;
            digits++;
        } while (temp != 0);
        bytes memory buffer = new bytes(digits);
        while (number != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + uint256(number % 10)));
            number /= 10;
        }
        return buffer;
    }

    function _verify(
        bytes32 hash,
        uint8[] calldata v,
        bytes32[] calldata r,
        bytes32[] calldata s
    ) internal view returns(uint256) {
        // кол-во админов, которые подписали это сообщение
        uint256 signed = 0;
        // массив админов, которые подписали сообщение
        address[] memory adrs = new address[](v.length);
        for(uint256 i = 0; i < v.length; i++) {
            // востонавливаем очередной адрес
            address adr = ecrecover(hash, v[i], r[i], s[i]);
            // проверяем ест-ли этот адрес среди админов
            if (admins[adr]) {
                bool check = true;
                // перебираем адреса тех, кто уже пописался, 
                // смотрим есть ли там адрес adr, 
                // если нет - добавляем
                for(uint256 j = 0; j < signed; j++) {
                    if (adr == adrs[j]) {
                        check = false;
                        break;
                    }
                }
                if (check) {
                    adrs[signed] = adr;
                    signed++;
                }
            }
        }
        return signed;
    }

    function lowLevelCall(address target, bytes calldata payload, uint256 value) internal returns(bool) {
        (bool success, ) = target.call{ value: value }(payload);
        require(success, "Not successfuly call");
        return success;
    }

}