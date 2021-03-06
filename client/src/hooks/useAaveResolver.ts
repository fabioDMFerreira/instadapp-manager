import { ethers } from "ethers";
import { useEffect, useState } from "react";

export interface AaveToken {
  address: string,
  name: string,
}

export default () => {
  const [tokens, ] = useState<AaveToken[]>([{
    name: "ETH",
    address: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
  }, {
    name: "DAI",
    address: "0x6b175474e89094c44da98b954eedeac495271d0f"
  }, {
    name: "Tether",
    address: "0xdac17f958d2ee523a2206206994597c13d831ec7"
  }, {
    name: "USD Coin",
    address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
  }, {
    name: "TrueUSD",
    address: "0x0000000000085d4780B73119b644AE5ecd22b376"
  }])

  return {
    tokens,
  };
}
