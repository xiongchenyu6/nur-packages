{ pkgs, config, lib, ... }:
with lib;
let
  file-path = builtins.split "/" (toString ./.);
  serviceName = lib.last file-path;
  cfg = config.services.${serviceName};
  fullNodeConfigFile = pkgs.writeText "${serviceName}.conf" ''
    net {
      type = mainnet
    }

    storage {
      # Directory for storing persistent data
      db.version = 2,
      db.engine = "LEVELDB",
      db.sync = false,
      db.directory = "database",
      index.directory = "index",
      transHistory.switch = "on"

      needToUpdateAsset = true

      dbSettings = {
        levelNumber = 7
        //compactThreads = 32
        blocksize = 64  // n * KB
        maxBytesForLevelBase = 256  // n * MB
        maxBytesForLevelMultiplier = 10
        level0FileNumCompactionTrigger = 4
        targetFileSizeBase = 256  // n * MB
        targetFileSizeMultiplier = 1
      }

      backup = {
        enable = false  // indicate whether enable the backup plugin
        propPath = "prop.properties" // record which bak directory is valid
        bak1path = "bak1/database" // you must set two backup directories to prevent application halt unexpected(e.g. kill -9).
        bak2path = "bak2/database"
        frequency = 10000   // indicate backup db once every 10000 blocks processed.
      }
    }

    node.discovery = {
      enable = true
      persist = true
      bind.ip = ""
      external.ip = null
    }

    node.backup {
      port = 10001
      # my priority, each member should use different priority
      priority = 8
      # peer's ip list, can't contain mine
      members = [
      ]
    }

    node {
      # trust node for solidity node
      # trustNode = "ip:port"
      trustNode = "127.0.0.1:50051"

      # expose extension api to public or not
      walletExtensionApi = true

      listen.port = 18888

      connection.timeout = 2

      tcpNettyWorkThreadNum = 0

      udpNettyWorkThreadNum = 1

      # Number of validate sign thread, default availableProcessors / 2
      # validateSignThreadNum = 16

      connectFactor = 0.3
      activeConnectFactor = 0.1

      maxActiveNodes = 30

      maxActiveNodesWithSameIp = 2

      maxHttpConnectNumber = 50

      minParticipationRate = 15

      # check the peer data transfer ,disconnect factor
      disconnectNumberFactor = 0.4
      maxConnectNumberFactor = 0.8
      receiveTcpMinDataLength = 2048
      isOpenFullTcpDisconnect = true

      metrics{
        prometheus{
         enable=true
         port=9527
        }
      }

      p2p {
        version = ${if (cfg.network == "mainnet") then "11111" else "201910292"}
      }

      active = []

      passive = []

      fastForward = [
        "100.26.245.209:18888",
        "15.188.6.125:18888"
      ]

      http {
        fullNodePort = 8090
        solidityPort = 8091
      }

      rpc {
        port = 50051
        maxConnectionIdleInMillis = 60000
        minEffectiveConnection = 1
      }
    }

    seed.node = {
      ip.list = [
        "3.225.171.164:18888",
        "52.53.189.99:18888",
        "18.196.99.16:18888",
        "34.253.187.192:18888",
        "18.133.82.227:18888",
        "35.180.51.163:18888",
        "54.252.224.209:18888",
        "18.231.27.82:18888",
        "52.15.93.92:18888",
        "34.220.77.106:18888",
        "15.207.144.3:18888",
        "13.124.62.58:18888",
        "13.229.128.108:18888",
        "35.182.37.246:18888",
        "34.200.228.125:18888",
        "18.220.232.201:18888",
        "13.57.30.186:18888",
        "35.165.103.105:18888",
        "18.184.238.21:18888",
        "34.250.140.143:18888",
        "35.176.192.130:18888",
        "52.47.197.188:18888",
        "52.62.210.100:18888",
        "13.231.4.243:18888",
        "18.231.76.29:18888",
        "35.154.90.144:18888",
        "13.125.210.234:18888",
        "13.250.40.82:18888",
        "35.183.101.48:18888"
      ]
    }

    genesis.block = {
      assets = [
        {
          accountName = "Zion"
          accountType = "AssetIssue"
          address = "TLLM21wteSPs4hKjbxgmH1L6poyMjeTbHm"
          balance = "99000000000000000"
        },
        {
          accountName = "Sun"
          accountType = "AssetIssue"
          address = "TXmVpin5vq5gdZsciyyjdZgKRUju4st1wM"
          balance = "0"
        },
        {
          accountName = "Blackhole"
          accountType = "AssetIssue"
          address = "TLsV52sRDL79HXGGm9yzwKibb6BeruhUzy"
          balance = "-9223372036854775808"
        }
      ]

      witnesses = [
        {
          address: THKJYuUmMKKARNf7s2VT51g5uPY6KEqnat,
          url = "http://GR1.com",
          voteCount = 100000026
        },
        {
          address: TVDmPWGYxgi5DNeW8hXrzrhY8Y6zgxPNg4,
          url = "http://GR2.com",
          voteCount = 100000025
        },
        {
          address: TWKZN1JJPFydd5rMgMCV5aZTSiwmoksSZv,
          url = "http://GR3.com",
          voteCount = 100000024
        },
        {
          address: TDarXEG2rAD57oa7JTK785Yb2Et32UzY32,
          url = "http://GR4.com",
          voteCount = 100000023
        },
        {
          address: TAmFfS4Tmm8yKeoqZN8x51ASwdQBdnVizt,
          url = "http://GR5.com",
          voteCount = 100000022
        },
        {
          address: TK6V5Pw2UWQWpySnZyCDZaAvu1y48oRgXN,
          url = "http://GR6.com",
          voteCount = 100000021
        },
        {
          address: TGqFJPFiEqdZx52ZR4QcKHz4Zr3QXA24VL,
          url = "http://GR7.com",
          voteCount = 100000020
        },
        {
          address: TC1ZCj9Ne3j5v3TLx5ZCDLD55MU9g3XqQW,
          url = "http://GR8.com",
          voteCount = 100000019
        },
        {
          address: TWm3id3mrQ42guf7c4oVpYExyTYnEGy3JL,
          url = "http://GR9.com",
          voteCount = 100000018
        },
        {
          address: TCvwc3FV3ssq2rD82rMmjhT4PVXYTsFcKV,
          url = "http://GR10.com",
          voteCount = 100000017
        },
        {
          address: TFuC2Qge4GxA2U9abKxk1pw3YZvGM5XRir,
          url = "http://GR11.com",
          voteCount = 100000016
        },
        {
          address: TNGoca1VHC6Y5Jd2B1VFpFEhizVk92Rz85,
          url = "http://GR12.com",
          voteCount = 100000015
        },
        {
          address: TLCjmH6SqGK8twZ9XrBDWpBbfyvEXihhNS,
          url = "http://GR13.com",
          voteCount = 100000014
        },
        {
          address: TEEzguTtCihbRPfjf1CvW8Euxz1kKuvtR9,
          url = "http://GR14.com",
          voteCount = 100000013
        },
        {
          address: TZHvwiw9cehbMxrtTbmAexm9oPo4eFFvLS,
          url = "http://GR15.com",
          voteCount = 100000012
        },
        {
          address: TGK6iAKgBmHeQyp5hn3imB71EDnFPkXiPR,
          url = "http://GR16.com",
          voteCount = 100000011
        },
        {
          address: TLaqfGrxZ3dykAFps7M2B4gETTX1yixPgN,
          url = "http://GR17.com",
          voteCount = 100000010
        },
        {
          address: TX3ZceVew6yLC5hWTXnjrUFtiFfUDGKGty,
          url = "http://GR18.com",
          voteCount = 100000009
        },
        {
          address: TYednHaV9zXpnPchSywVpnseQxY9Pxw4do,
          url = "http://GR19.com",
          voteCount = 100000008
        },
        {
          address: TCf5cqLffPccEY7hcsabiFnMfdipfyryvr,
          url = "http://GR20.com",
          voteCount = 100000007
        },
        {
          address: TAa14iLEKPAetX49mzaxZmH6saRxcX7dT5,
          url = "http://GR21.com",
          voteCount = 100000006
        },
        {
          address: TBYsHxDmFaRmfCF3jZNmgeJE8sDnTNKHbz,
          url = "http://GR22.com",
          voteCount = 100000005
        },
        {
          address: TEVAq8dmSQyTYK7uP1ZnZpa6MBVR83GsV6,
          url = "http://GR23.com",
          voteCount = 100000004
        },
        {
          address: TRKJzrZxN34YyB8aBqqPDt7g4fv6sieemz,
          url = "http://GR24.com",
          voteCount = 100000003
        },
        {
          address: TRMP6SKeFUt5NtMLzJv8kdpYuHRnEGjGfe,
          url = "http://GR25.com",
          voteCount = 100000002
        },
        {
          address: TDbNE1VajxjpgM5p7FyGNDASt3UVoFbiD3,
          url = "http://GR26.com",
          voteCount = 100000001
        },
        {
          address: TLTDZBcPoJ8tZ6TTEeEqEvwYFk2wgotSfD,
          url = "http://GR27.com",
          voteCount = 100000000
        }
      ]

      timestamp = "0" #2017-8-26 12:00:00

      parentHash = "0xe58f33f9baf9305dc6f82b9f1934ea8f0ade2defb951258d50167028c780351f"
    }

    // Optional.The default is empty.
    // It is used when the witness account has set the witnessPermission.
    // When it is not empty, the localWitnessAccountAddress represents the address of the witness account,
    // and the localwitness is configured with the private key of the witnessPermissionAddress in the witness account.
    // When it is empty,the localwitness is configured with the private key of the witness account.

    //localWitnessAccountAddress =

    localwitness = [
    ]

    block = {
      needSyncCheck = true
      maintenanceTimeInterval = 21600000
      proposalExpireTime = 259200000 // 3 day: 259200000(ms)
    }

    # Transaction reference block, default is "head", configure to "solid" can avoid TaPos error
    trx.reference.block = "solid" // head;solid;

    # This property sets the number of milliseconds after the creation of the transaction that is expired, default value is  60000.
    # trx.expiration.timeInMilliseconds = 60000

    vm = {
      supportConstant = false
      minTimeRatio = 0.0
      maxTimeRatio = 5.0
      saveInternalTx = false

      # In rare cases, transactions that will be within the specified maximum execution time (default 10(ms)) are re-executed and packaged
      # longRunningTime = 10
    }

    committee = {
      allowCreationOfContracts = 0  //mainnet:0 (reset by committee),test:1
      allowAdaptiveEnergy = 0  //mainnet:0 (reset by committee),test:1
    }

    event.subscribe = {
        path = "${

          if (cfg.event-plugin == "mongodb") then
            "/var/lib/${serviceName}/plugin-mongodb.zip"
          else
            ""
        }" // absolute path of plugin
        server = "${
          if (cfg.event-plugin == "mongodb") then
            "${cfg.db-host}:${toString cfg.db-port}"
          else
            ""
        }" // target server address to receive event triggers
        dbconfig="${
          if (cfg.event-plugin == "mongodb") then
            "${cfg.db-name}|${cfg.db-user}|${cfg.db-pass}"
          else
            ""
        }" // dbname|username|password
        topics = [
            {
              triggerName = "block" // block trigger, the value can't be modified
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              }
              topic = "block" // plugin topic, the value could be modified
            },
            {
              triggerName = "transaction"
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              }
              topic = "transaction"
            },
            {
              triggerName = "contractevent"
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              } // enable or disable this trigger
              topic = "contractevent"
            },
            {
              triggerName = "contractlog"
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              } // enable or disable this trigger
              topic = "contractlog"
              redundancy = true
            },
            {
              triggerName = "solidity" // solidity block event trigger, the value can't be modified
              enable = true            // the default value is true
              topic = "solidity"
            },
            {
              triggerName = "solidityevent"
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              }
              topic = "solidityevent"
            },
            {
              triggerName = "soliditylog"
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              }
              topic = "soliditylog"
              redundancy = true
            }
        ]

        filter = {
           fromblock = "" // the value could be "", "earliest" or a specified block number as the beginning of the queried range
           toblock = "" // the value could be "", "latest" or a specified block number as end of the queried range
           contractAddress = [
               "" // contract address you want to subscribe, if it's set to "", you will receive contract logs/events with any contract address.
           ]

           contractTopic = [
               "" // contract topic you want to subscribe, if it's set to "", you will receive contract logs/events with any contract topic.
           ]
        }
    }
  '';
  solidityNodeConfigFile = pkgs.writeText "${serviceName}.conf" ''
    net {
      type = mainnet
    }

    storage {
      # Directory for storing persistent data
      db.version = 2,
      db.engine = "LEVELDB",
      db.sync = false,
      db.directory = "database",
      index.directory = "index",
      transHistory.switch = "on"

      needToUpdateAsset = true

      dbSettings = {
        levelNumber = 7
        //compactThreads = 32
        blocksize = 64  // n * KB
        maxBytesForLevelBase = 256  // n * MB
        maxBytesForLevelMultiplier = 10
        level0FileNumCompactionTrigger = 4
        targetFileSizeBase = 256  // n * MB
        targetFileSizeMultiplier = 1
      }

      backup = {
        enable = false  // indicate whether enable the backup plugin
        propPath = "prop.properties" // record which bak directory is valid
        bak1path = "bak1/database" // you must set two backup directories to prevent application halt unexpected(e.g. kill -9).
        bak2path = "bak2/database"
        frequency = 10000   // indicate backup db once every 10000 blocks processed.
      }
    }

    node.discovery = {
      enable = true
      persist = true
      bind.ip = ""
      external.ip = null
    }

    node.backup {
      port = 10001
      # my priority, each member should use different priority
      priority = 8
      # peer's ip list, can't contain mine
      members = [
      ]
    }

    node {
      # trust node for solidity node
      # trustNode = "ip:port"
      trustNode = "127.0.0.1:50051"

      # expose extension api to public or not
      walletExtensionApi = true

      listen.port = 18888

      connection.timeout = 2

      tcpNettyWorkThreadNum = 0

      udpNettyWorkThreadNum = 1

      # Number of validate sign thread, default availableProcessors / 2
      # validateSignThreadNum = 16

      connectFactor = 0.3
      activeConnectFactor = 0.1

      maxActiveNodes = 30

      maxActiveNodesWithSameIp = 2

      maxHttpConnectNumber = 50

      minParticipationRate = 15

      # check the peer data transfer ,disconnect factor
      disconnectNumberFactor = 0.4
      maxConnectNumberFactor = 0.8
      receiveTcpMinDataLength = 2048
      isOpenFullTcpDisconnect = true

      p2p {
        version = ${if (cfg.network == "mainnet") then "11111" else "201910292"}
      }

      active = []

      passive = []

      fastForward = [
        "100.26.245.209:18888",
        "15.188.6.125:18888"
      ]

      http {
        fullNodePort = 8090
        solidityPort = 8091
      }

      rpc {
        port = 50052
        maxConnectionIdleInMillis = 60000
        minEffectiveConnection = 1
      }
    }

    seed.node = {
      ip.list = [
        "3.225.171.164:18888",
        "52.53.189.99:18888",
        "18.196.99.16:18888",
        "34.253.187.192:18888",
        "18.133.82.227:18888",
        "35.180.51.163:18888",
        "54.252.224.209:18888",
        "18.231.27.82:18888",
        "52.15.93.92:18888",
        "34.220.77.106:18888",
        "15.207.144.3:18888",
        "13.124.62.58:18888",
        "13.229.128.108:18888",
        "35.182.37.246:18888",
        "34.200.228.125:18888",
        "18.220.232.201:18888",
        "13.57.30.186:18888",
        "35.165.103.105:18888",
        "18.184.238.21:18888",
        "34.250.140.143:18888",
        "35.176.192.130:18888",
        "52.47.197.188:18888",
        "52.62.210.100:18888",
        "13.231.4.243:18888",
        "18.231.76.29:18888",
        "35.154.90.144:18888",
        "13.125.210.234:18888",
        "13.250.40.82:18888",
        "35.183.101.48:18888"
      ]
    }

    genesis.block = {
      assets = [
        {
          accountName = "Zion"
          accountType = "AssetIssue"
          address = "TLLM21wteSPs4hKjbxgmH1L6poyMjeTbHm"
          balance = "99000000000000000"
        },
        {
          accountName = "Sun"
          accountType = "AssetIssue"
          address = "TXmVpin5vq5gdZsciyyjdZgKRUju4st1wM"
          balance = "0"
        },
        {
          accountName = "Blackhole"
          accountType = "AssetIssue"
          address = "TLsV52sRDL79HXGGm9yzwKibb6BeruhUzy"
          balance = "-9223372036854775808"
        }
      ]

      witnesses = [
        {
          address: THKJYuUmMKKARNf7s2VT51g5uPY6KEqnat,
          url = "http://GR1.com",
          voteCount = 100000026
        },
        {
          address: TVDmPWGYxgi5DNeW8hXrzrhY8Y6zgxPNg4,
          url = "http://GR2.com",
          voteCount = 100000025
        },
        {
          address: TWKZN1JJPFydd5rMgMCV5aZTSiwmoksSZv,
          url = "http://GR3.com",
          voteCount = 100000024
        },
        {
          address: TDarXEG2rAD57oa7JTK785Yb2Et32UzY32,
          url = "http://GR4.com",
          voteCount = 100000023
        },
        {
          address: TAmFfS4Tmm8yKeoqZN8x51ASwdQBdnVizt,
          url = "http://GR5.com",
          voteCount = 100000022
        },
        {
          address: TK6V5Pw2UWQWpySnZyCDZaAvu1y48oRgXN,
          url = "http://GR6.com",
          voteCount = 100000021
        },
        {
          address: TGqFJPFiEqdZx52ZR4QcKHz4Zr3QXA24VL,
          url = "http://GR7.com",
          voteCount = 100000020
        },
        {
          address: TC1ZCj9Ne3j5v3TLx5ZCDLD55MU9g3XqQW,
          url = "http://GR8.com",
          voteCount = 100000019
        },
        {
          address: TWm3id3mrQ42guf7c4oVpYExyTYnEGy3JL,
          url = "http://GR9.com",
          voteCount = 100000018
        },
        {
          address: TCvwc3FV3ssq2rD82rMmjhT4PVXYTsFcKV,
          url = "http://GR10.com",
          voteCount = 100000017
        },
        {
          address: TFuC2Qge4GxA2U9abKxk1pw3YZvGM5XRir,
          url = "http://GR11.com",
          voteCount = 100000016
        },
        {
          address: TNGoca1VHC6Y5Jd2B1VFpFEhizVk92Rz85,
          url = "http://GR12.com",
          voteCount = 100000015
        },
        {
          address: TLCjmH6SqGK8twZ9XrBDWpBbfyvEXihhNS,
          url = "http://GR13.com",
          voteCount = 100000014
        },
        {
          address: TEEzguTtCihbRPfjf1CvW8Euxz1kKuvtR9,
          url = "http://GR14.com",
          voteCount = 100000013
        },
        {
          address: TZHvwiw9cehbMxrtTbmAexm9oPo4eFFvLS,
          url = "http://GR15.com",
          voteCount = 100000012
        },
        {
          address: TGK6iAKgBmHeQyp5hn3imB71EDnFPkXiPR,
          url = "http://GR16.com",
          voteCount = 100000011
        },
        {
          address: TLaqfGrxZ3dykAFps7M2B4gETTX1yixPgN,
          url = "http://GR17.com",
          voteCount = 100000010
        },
        {
          address: TX3ZceVew6yLC5hWTXnjrUFtiFfUDGKGty,
          url = "http://GR18.com",
          voteCount = 100000009
        },
        {
          address: TYednHaV9zXpnPchSywVpnseQxY9Pxw4do,
          url = "http://GR19.com",
          voteCount = 100000008
        },
        {
          address: TCf5cqLffPccEY7hcsabiFnMfdipfyryvr,
          url = "http://GR20.com",
          voteCount = 100000007
        },
        {
          address: TAa14iLEKPAetX49mzaxZmH6saRxcX7dT5,
          url = "http://GR21.com",
          voteCount = 100000006
        },
        {
          address: TBYsHxDmFaRmfCF3jZNmgeJE8sDnTNKHbz,
          url = "http://GR22.com",
          voteCount = 100000005
        },
        {
          address: TEVAq8dmSQyTYK7uP1ZnZpa6MBVR83GsV6,
          url = "http://GR23.com",
          voteCount = 100000004
        },
        {
          address: TRKJzrZxN34YyB8aBqqPDt7g4fv6sieemz,
          url = "http://GR24.com",
          voteCount = 100000003
        },
        {
          address: TRMP6SKeFUt5NtMLzJv8kdpYuHRnEGjGfe,
          url = "http://GR25.com",
          voteCount = 100000002
        },
        {
          address: TDbNE1VajxjpgM5p7FyGNDASt3UVoFbiD3,
          url = "http://GR26.com",
          voteCount = 100000001
        },
        {
          address: TLTDZBcPoJ8tZ6TTEeEqEvwYFk2wgotSfD,
          url = "http://GR27.com",
          voteCount = 100000000
        }
      ]

      timestamp = "0" #2017-8-26 12:00:00

      parentHash = "0xe58f33f9baf9305dc6f82b9f1934ea8f0ade2defb951258d50167028c780351f"
    }

    // Optional.The default is empty.
    // It is used when the witness account has set the witnessPermission.
    // When it is not empty, the localWitnessAccountAddress represents the address of the witness account,
    // and the localwitness is configured with the private key of the witnessPermissionAddress in the witness account.
    // When it is empty,the localwitness is configured with the private key of the witness account.

    //localWitnessAccountAddress =

    localwitness = [
    ]

    block = {
      needSyncCheck = false
      maintenanceTimeInterval = 21600000
      proposalExpireTime = 259200000 // 3 day: 259200000(ms)
    }

    # Transaction reference block, default is "head", configure to "solid" can avoid TaPos error
    trx.reference.block = "solid" // head;solid;

    # This property sets the number of milliseconds after the creation of the transaction that is expired, default value is  60000.
    # trx.expiration.timeInMilliseconds = 60000

    vm = {
      supportConstant = false
      minTimeRatio = 0.0
      maxTimeRatio = 5.0
      saveInternalTx = false

      # In rare cases, transactions that will be within the specified maximum execution time (default 10(ms)) are re-executed and packaged
      # longRunningTime = 10
    }

    committee = {
      allowCreationOfContracts = 0  //mainnet:0 (reset by committee),test:1
      allowAdaptiveEnergy = 0  //mainnet:0 (reset by committee),test:1
    }

    event.subscribe = {
        path = "${

          if (cfg.event-plugin == "mongodb") then
            "/var/lib/${serviceName}/plugin-mongodb.zip"
          else
            ""
        }" // absolute path of plugin
        server = "${
          if (cfg.event-plugin == "mongodb") then
            "${cfg.db-host}:${toString cfg.db-port}"
          else
            ""
        }" // target server address to receive event triggers
        dbconfig="${
          if (cfg.event-plugin == "mongodb") then
            "${cfg.db-name}|${cfg.db-user}|${cfg.db-pass}"
          else
            ""
        }" // dbname|username|password
        topics = [
            {
              triggerName = "block" // block trigger, the value can't be modified
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              }
              topic = "block" // plugin topic, the value could be modified
            },
            {
              triggerName = "transaction"
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              }
              topic = "transaction"
            },
            {
              triggerName = "contractevent"
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              } // enable or disable this trigger
              topic = "contractevent"
            },
            {
              triggerName = "contractlog"
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              } // enable or disable this trigger
              topic = "contractlog"
              redundancy = true
            },
            {
              triggerName = "solidity" // solidity block event trigger, the value can't be modified
              enable = true            // the default value is true
              topic = "solidity"
            },
            {
              triggerName = "solidityevent"
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              }
              topic = "solidityevent"
            },
            {
              triggerName = "soliditylog"
              enable = ${
                if (cfg.event-plugin != "none") then "true" else "false"
              }
              topic = "soliditylog"
              redundancy = true
            }
        ]

        filter = {
           fromblock = "" // the value could be "", "earliest" or a specified block number as the beginning of the queried range
           toblock = "" // the value could be "", "latest" or a specified block number as end of the queried range
           contractAddress = [
               "" // contract address you want to subscribe, if it's set to "", you will receive contract logs/events with any contract address.
           ]

           contractTopic = [
               "" // contract topic you want to subscribe, if it's set to "", you will receive contract logs/events with any contract topic.
           ]
        }
    }
  '';
in {
  options.services = {
    "${serviceName}" = {
      enable = mkEnableOption "Enables ${serviceName} service";

      enableWitness = mkOption {
        type = types.bool;
        default = false;
        description = "Enables witness service";
      };

      enableSolidityNode = mkOption {
        type = types.bool;
        default = false;
        description = "Enables solidity node service";
      };

      enableEventQuery = mkOption {
        type = types.bool;
        default = false;
        description = "Enables event query service";
      };

      privateKey = mkOption {
        type = types.str;
        default = "";
        description = "Private key for ${serviceName}";
      };

      network = mkOption {
        type = types.enum [ "mainnet" "testnet" "privatenet" ];
        default = "mainnet";
        description = "Network for ${serviceName}";
      };

      event-plugin = mkOption {
        type = types.enum [ "none" "mongodb" "kafka" ];
        default = "none";
        description = "Event plugin for ${serviceName}";
      };

      db-path = mkOption {
        type = types.str;
        default = "output-directory";
        description = lib.mdDoc "Location where MongoDB stores its files";
      };

      db-host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Database host for ${serviceName}";
      };

      db-port = mkOption {
        type = types.int;
        default = 27017;
        description = "Database port for ${serviceName}";
      };
      db-name = mkOption {
        type = types.str;
        default = "eventlog";
        description = "Database name for ${serviceName}";
      };
      db-user = mkOption {
        type = types.str;
        default = "tron";
        description = "Database user for ${serviceName}";
      };
      db-pass = mkOption {
        type = types.str;
        default = "123456";
        description = "Database password for ${serviceName}";
      };
    };
  };
  config = mkIf cfg.enable {
    systemd = {
      services = let
        serviceConfig = {
          User = serviceName;
          Restart = "on-failure";
          RestartSec = "10s";
          WorkingDirectory = "/var/lib/${serviceName}";
          StateDirectory = serviceName;
          RuntimeDirectory = serviceName;
          CacheDirectory = serviceName;
          RuntimeDirectoryMode = "0755";
          StateDirectoryMode = "0700";
          CacheDirectoryMode = "0750";
        };
      in {
        "${serviceName}-full-node" = {
          inherit serviceConfig;
          wantedBy = [ "multi-user.target" ];
          after = [ "networking.target" ];
          startLimitIntervalSec = 500;
          startLimitBurst = 5;
          onSuccess = [ ];
          onFailure = [ ];
          bindsTo = if (cfg.event-plugin == "mongodb") then
            [ "mongodb.service" ]
          else if (cfg.event-plugin == "kafka") then
            [ "kafka.service" ]
          else
            [ ];
          preStart = ''
            if ! test -e ${cfg.db-path}; then
                install -d -m0700 -o ${serviceName} ${cfg.db-path}
            fi

            if ! test -e /var/lib/${serviceName}/plugin-mongodb.zip; then
              cp ${pkgs.java-tron}/lib/plugin-mongodb.zip /var/lib/${serviceName}/plugin-mongodb.zip
            fi
          '';

          script = ''
            ${pkgs.java-tron}/bin/java-tron-full-node -d ${cfg.db-path} -c ${fullNodeConfigFile} ${
              if (cfg.event-plugin != "none") then "--es" else ""
            } ${
              if (cfg.enableWitness == null) then
                "--witness -p ${cfg.privateKey}"
              else
                ""
            }
          '';
        };
        "${serviceName}-solidity-node" = mkIf cfg.enableSolidityNode {
          inherit serviceConfig;
          wantedBy = [ "multi-user.target" ];
          after = [ "networking.target" ];
          startLimitIntervalSec = 500;
          startLimitBurst = 5;
          onSuccess = [ ];
          onFailure = [ ];
          bindsTo = [ "${serviceName}-full-node.service" ];
          preStart = ''
            if ! test -e solidity-node; then
                install -d -m0700 -o ${serviceName} solidity-node
            fi

            if ! test -e ${cfg.db-path}/solidity-node; then
                install -d -m0700 -o ${serviceName} ${cfg.db-path}/solidity-node
            fi
          '';

          script = ''
            cd solidity-node
            ${pkgs.java-tron}/bin/java-tron-solidity-node -d ${cfg.db-path}/solidity-node -c ${solidityNodeConfigFile} ${
              if (cfg.event-plugin != "none") then "--es" else ""
            } ${
              if (cfg.enableWitness == null) then
                "--witness -p ${cfg.privateKey}"
              else
                ""
            }
          '';
        };

        tron-eventquery = mkIf cfg.enableEventQuery {
          inherit serviceConfig;
          bindsTo = [ "${serviceName}-full-node.service" ];
          script = ''
            ${pkgs.tron-eventquery}/bin/tron-eventquery \
            --mongo.host=${cfg.db-host} \
            --mongo.port=${toString cfg.db-port} \
            --mongo.dbname=${cfg.db-name} \
            --mongo.username=${cfg.db-user} \
            --mongo.password=${cfg.db-pass} \
            --mongo.connectionsPerHost=200 \
            --mongo.threadsAllowedToBlockForConnectionMultiplier=10 \
            --mongo.deadline=10
          '';
        };
      };
    };
    users.users."${serviceName}" = {
      description = "${serviceName} user";
      isSystemUser = true;
      group = serviceName;
    };
    users.groups."${serviceName}" = { };
  };
}
