import { Hash, parseEther } from "viem";
import { IrmDeployFnParams } from "../types";

export const deployIRMs = async ({
  viem,
  getNamedAccounts,
  deployments,
  deployConfig
}: IrmDeployFnParams): Promise<void> => {
  const publicClient = await viem.getPublicClient();
  const { deployer } = await getNamedAccounts();
  //// IRM MODELS|
  const jrm = await deployments.deploy("JumpRateModel", {
    from: deployer,
    args: [
      deployConfig.blocksPerYear,
      parseEther("0").toString(), // baseRatePerYear   0
      parseEther("0.18").toString(), // multiplierPerYear 0.18
      parseEther("4").toString(), //jumpMultiplierPerYear 4
      parseEther("0.8").toString() // kink               0.8
    ],
    log: true
  });
  if (jrm.transactionHash) await publicClient.waitForTransactionReceipt({ hash: jrm.transactionHash as Hash });
  console.log("JumpRateModel: ", jrm.address);
};
