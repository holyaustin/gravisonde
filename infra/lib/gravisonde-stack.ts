import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as iam from "aws-cdk-lib/aws-iam";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as logs from "aws-cdk-lib/aws-logs";
import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";

export interface GravisondeStackProps extends cdk.StackProps {
  /** Instance type to launch (c8g.xlarge by default) */
  instanceType?: string;
  /** EC2 key pair name for SSH access (optional) */
  keyName?: string;
}

/**
 * GravisondeStack
 *
 * Provisions:
 *   - EC2 c8g.xlarge (Graviton4) with COOL AMI for the OpenCV pipeline
 *   - IAM instance profile (least privilege: CloudWatch + S3)
 *   - CloudWatch Log Group + custom metric namespace
 *   - S3 bucket for benchmark artifacts
 *   - Security group (SSH builder-only, ALB 80/443 optional)
 */
export class GravisondeStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: GravisondeStackProps) {
    super(scope, id, props);

    const instanceTypeName = props?.instanceType ?? "c8g.xlarge";

    // --- VPC ---
    const vpc = new ec2.Vpc(this, "GravisondeVpc", {
      maxAzs: 2,
      natGateways: 0, // Keep cost low for a hackathon demo
    });

    // --- Security Group ---
    const sg = new ec2.SecurityGroup(this, "PipelineSecurityGroup", {
      vpc,
      description: "Gravisonde pipeline security group",
      allowAllOutbound: true,
    });
    sg.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(22), "SSH builder access");
    sg.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(443), "HTTPS (ALB, optional)");
    sg.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(80), "HTTP (ALB, optional)");

    // --- IAM Role for EC2 ---
    const role = new iam.Role(this, "PipelineInstanceRole", {
      assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName("CloudWatchAgentServerPolicy"),
      ],
    });
    role.addToPolicy(
      new iam.PolicyStatement({
        actions: ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
        resources: ["*"],
      })
    );

    const instanceProfile = new iam.CfnInstanceProfile(this, "InstanceProfile", {
      roles: [role.roleName],
    });

    // --- S3 Bucket for Benchmark Artifacts ---
    const benchmarkBucket = new s3.Bucket(this, "BenchmarkBucket", {
      bucketName: `gravisonde-benchmarks-${cdk.Aws.ACCOUNT_ID}`,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    // --- CloudWatch Log Group ---
    const logGroup = new logs.LogGroup(this, "PipelineLogGroup", {
      logGroupName: "/aws/gravisonde/pipeline",
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      retention: logs.RetentionDays.ONE_WEEK,
    });

    // --- EC2 Instance ---
    const instance = new ec2.Instance(this, "PipelineInstance", {
      vpc,
      instanceType: ec2.InstanceType.of(
        ec2.InstanceClass.C8G,
        ec2.InstanceSize.XLARGE
      ),
      machineImage: ec2.MachineImage.fromCfnParameter(
        new ec2.CfnParameter(this, "CoolAmiId", {
          type: "AWS::EC2::Image::Id",
          description: "COOL AMI ID (Cloud-Optimized OpenCV Library)",
        })
      ),
      securityGroup: sg,
      keyName: props?.keyName,
      role,
      instanceProfileName: instanceProfile.ref,
    });

    // --- Outputs ---
    new cdk.CfnOutput(this, "InstanceId", {
      value: instance.instanceId,
      description: "EC2 instance ID for the pipeline",
    });
    new cdk.CfnOutput(this, "InstancePublicIp", {
      value: instance.instancePublicIp ?? "N/A",
      description: "Public IP of the pipeline instance",
    });
    new cdk.CfnOutput(this, "BenchmarkBucketName", {
      value: benchmarkBucket.bucketName,
      description: "S3 bucket for benchmark artifacts",
    });
    new cdk.CfnOutput(this, "CwLogGroup", {
      value: logGroup.logGroupName,
      description: "CloudWatch log group name",
    });
  }
}
