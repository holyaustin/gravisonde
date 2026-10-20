#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { GravisondeStack } from "../lib/gravisonde-stack";

const app = new cdk.App();

new GravisondeStack(app, "GravisondeStack", {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || "us-east-1",
  },
  description: "Gravisonde — OpenCV 5 COOL benchmark infrastructure",
});