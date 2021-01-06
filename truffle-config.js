const HDWalletProvider = require("truffle-hdwallet-provider");;

module.exports = {
  // Uncommenting the defaults below 
  // provides for an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  //
  //networks: {
  //  development: {
  //    host: "127.0.0.1",
  //    port: 7545,
  //    network_id: "*"
  //  },
  ropsten: {
    network_id: '3',
    provider: () => new HDWalletProvider(
      "tower glimpse provide leg travel define gaze mind forum run flavor media",
      'wss://ropsten.infura.io/ws/v3/2178f38fc5bc4fe58da2817ea1ded427',
    ),
    gasPrice: 10000000000, // 10 gwei
    gas: 6000000,
    skipDryRun: true,
    timeoutBlocks: 8000,
  },
  //  test: {
  //    host: "127.0.0.1",
  //    port: 7545,
  //    network_id: "*"
  //  }
  //}
  //
};
