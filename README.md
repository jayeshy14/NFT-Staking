# Hardhat Project

This is a Hardhat project used for developing, deploying, and testing Ethereum smart contracts.

## Getting Started

Follow these instructions to get a copy of the project and running the hardhat project on your local machine for development and testing purposes.

### Prerequisites

Make sure you have the following installed on your machine:

- [Node.js](https://nodejs.org/)
- [npm](https://www.npmjs.com/) or [yarn](https://yarnpkg.com/)
- [Git](https://git-scm.com/)

### Installing, Testing and Deploying

1. **Clone the repository:**

   ```sh
   git clone https://github.com/jayeshy14/NFT-Staking/.git
   cd NFT-Staking

2. **Start the Hardhat Node**

   ```sh
   npx hardhat node

3. **Compile the Contracts**

   ```sh
   npx hardhat compile
   
4. **Test the Contract**

   ```sh
   npx hardhat test

5. **Deploy the Contracts**

   ```sh
   npx hardhat run scripts/deploy.js --network localhost
