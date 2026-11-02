#!/bin/bash
# fix-ec2-ssh.sh
# Diagnose and fix EC2 SSH connection issues
# Usage: ./fix-ec2-ssh.sh

set -e

# Configuration
EC2_IP="16.16.75.56"
KEY_PATH="/home/augustineonuora/.ssh/gravisonde-aws-key1.pem"
REGION="eu-north-1"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   EC2 SSH Connection Fixer                           ║
║   Diagnose and fix security group issues             ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Target EC2: $EC2_IP"
echo "Region: $REGION"
echo ""

# =============================================================================
# Step 1: Check Prerequisites
# =============================================================================
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not installed${NC}"
    echo "Install with:"
    echo "  curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
    echo "  unzip awscliv2.zip"
    echo "  sudo ./aws/install"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI installed${NC}"

# Check AWS credentials
if ! aws sts get-caller-identity --region $REGION > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ AWS credentials not configured or expired${NC}"
    echo ""
    echo "Configure with:"
    echo "  aws configure"
    echo ""
    echo "Or export credentials:"
    echo "  export AWS_ACCESS_KEY_ID=your_key"
    echo "  export AWS_SECRET_ACCESS_KEY=your_secret"
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ AWS credentials configured${NC}"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
    echo "  Account ID: $ACCOUNT_ID"
fi

# Check SSH key
if [ ! -f "$KEY_PATH" ]; then
    echo -e "${RED}✗ SSH key not found: $KEY_PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH key found${NC}"

# Check key permissions
KEY_PERMS=$(stat -c %a "$KEY_PATH" 2>/dev/null || stat -f %A "$KEY_PATH")
if [ "$KEY_PERMS" != "400" ] && [ "$KEY_PERMS" != "600" ]; then
    echo -e "${YELLOW}⚠ SSH key permissions are $KEY_PERMS (should be 400)${NC}"
    echo "  Fixing permissions..."
    chmod 400 "$KEY_PATH"
    echo -e "${GREEN}✓ Fixed to 400${NC}"
else
    echo -e "${GREEN}✓ SSH key permissions OK ($KEY_PERMS)${NC}"
fi

echo ""

# =============================================================================
# Step 2: Check Network Connectivity
# =============================================================================
echo -e "${BLUE}Step 2: Checking network connectivity...${NC}"
echo ""

# Ping test
echo "Testing ICMP (ping)..."
if ping -c 2 -W 3 $EC2_IP > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Host is reachable (ICMP)${NC}"
else
    echo -e "${YELLOW}⚠ Host not reachable via ICMP (may be blocked)${NC}"
fi

# Port 22 test
echo ""
echo "Testing SSH port 22..."
if timeout 5 bash -c "echo >/dev/tcp/$EC2_IP/22" 2>/dev/null; then
    echo -e "${GREEN}✓ Port 22 is OPEN${NC}"
    echo ""
    echo -e "${GREEN}Port 22 is accessible! The issue may be with SSH keys or instance state.${NC}"
else
    echo -e "${RED}✗ Port 22 is CLOSED or FILTERED${NC}"
    echo ""
    echo -e "${YELLOW}This is the problem! Security group is blocking SSH.${NC}"
    PORT_BLOCKED=true
fi

echo ""

# =============================================================================
# Step 3: Get Instance Information
# =============================================================================
echo -e "${BLUE}Step 3: Getting EC2 instance information...${NC}"
echo ""

# Find instance by IP
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=ip-address,Values=$EC2_IP" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text \
    --region $REGION 2>/dev/null || echo "None")

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo -e "${YELLOW}⚠ Could not find instance with IP $EC2_IP${NC}"
    echo ""
    echo "Listing all running instances in $REGION:"
    aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]" \
        --output table \
        --region $REGION 2>/dev/null || echo "Failed to list instances"
    echo ""
    read -p "Enter the correct Instance ID manually: " INSTANCE_ID
fi

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
    echo -e "${RED}✗ No instance ID provided${NC}"
    exit 1
fi

echo "Instance ID: $INSTANCE_ID"

# Get instance details
echo ""
echo "Fetching instance details..."

INSTANCE_STATE=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query "Reservations[0].Instances[0].State.Name" \
    --output text \
    --region $REGION 2>/dev/null || echo "unknown")

SECURITY_GROUP_ID=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" \
    --output text \
    --region $REGION 2>/dev/null || echo "unknown")

PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text \
    --region $REGION 2>/dev/null || echo "unknown")

echo "  State: $INSTANCE_STATE"
echo "  Public IP: $PUBLIC_IP"
echo "  Security Group: $SECURITY_GROUP_ID"

if [ "$INSTANCE_STATE" != "running" ]; then
    echo -e "${RED}✗ Instance is not running!${NC}"
    echo ""
    read -p "Do you want to start the instance? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Starting instance..."
        aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION
        echo "Waiting for instance to start..."
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION
        echo -e "${GREEN}✓ Instance started${NC}"

        # Get new public IP
        PUBLIC_IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query "Reservations[0].Instances[0].PublicIpAddress" \
            --output text \
            --region $REGION)
        echo "New Public IP: $PUBLIC_IP"

        if [ "$PUBLIC_IP" != "$EC2_IP" ]; then
            echo -e "${YELLOW}⚠ Public IP has changed!${NC}"
            echo "  Old IP: $EC2_IP"
            echo "  New IP: $PUBLIC_IP"
            EC2_IP=$PUBLIC_IP
        fi
    else
        exit 1
    fi
fi

echo ""

# =============================================================================
# Step 4: Check Security Group Rules
# =============================================================================
echo -e "${BLUE}Step 4: Checking security group rules...${NC}"
echo ""

if [ "$SECURITY_GROUP_ID" != "unknown" ]; then
    echo "Security Group ID: $SECURITY_GROUP_ID"
    echo ""
    echo "Current inbound rules:"

    aws ec2 describe-security-groups \
        --group-ids $SECURITY_GROUP_ID \
        --query "SecurityGroups[0].IpPermissions[].[IpProtocol,FromPort,ToPort,IpRanges[].CidrIp]" \
        --output table \
        --region $REGION 2>/dev/null || echo "Failed to get security group rules"

    echo ""

    # Check if SSH rule exists
    SSH_RULE=$(aws ec2 describe-security-groups \
        --group-ids $SECURITY_GROUP_ID \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`]" \
        --output json \
        --region $REGION 2>/dev/null || echo "[]")

    if [ "$SSH_RULE" = "[]" ] || [ -z "$SSH_RULE" ]; then
        echo -e "${RED}✗ No SSH rule found in security group${NC}"
        SSH_RULE_EXISTS=false
    else
        echo -e "${YELLOW}⚠ SSH rule exists but may not allow your IP${NC}"
        SSH_RULE_EXISTS=true
    fi
else
    echo -e "${YELLOW}⚠ Could not retrieve security group ID${NC}"
    SSH_RULE_EXISTS=false
fi

echo ""

# =============================================================================
# Step 5: Fix Security Group
# =============================================================================
if [ "$PORT_BLOCKED" = true ] || [ "$SSH_RULE_EXISTS" = false ]; then
    echo -e "${BLUE}Step 5: Fixing security group...${NC}"
    echo ""

    # Get current public IP
    MY_IP=$(curl -s https://api.ipify.org 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null || echo "unknown")

    if [ "$MY_IP" = "unknown" ]; then
        echo -e "${YELLOW}⚠ Could not detect your public IP${NC}"
        read -p "Enter your public IP address: " MY_IP
    fi

    echo "Your public IP: $MY_IP"
    echo ""

    echo "Security group fix options:"
    echo "  1) Add SSH rule for your IP only ($MY_IP/32) [RECOMMENDED]"
    echo "  2) Add SSH rule for anywhere (0.0.0.0/0) [INSECURE - NOT RECOMMENDED]"
    echo "  3) Skip (fix manually in AWS Console)"
    echo ""
    read -p "Choose option (1/2/3): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[1]$ ]]; then
        CIDR="$MY_IP/32"
        echo "Adding SSH rule for $CIDR..."

        aws ec2 authorize-security-group-ingress \
            --group-id $SECURITY_GROUP_ID \
            --protocol tcp \
            --port 22 \
            --cidr $CIDR \
            --region $REGION

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ SSH rule added successfully${NC}"
        else
            echo -e "${RED}✗ Failed to add SSH rule${NC}"
            echo "You may need to add it manually in AWS Console"
        fi

    elif [[ $REPLY =~ ^[2]$ ]]; then
        echo -e "${RED}WARNING: This opens SSH to the entire internet!${NC}"
        read -p "Are you sure? (yes/no): " CONFIRM

        if [ "$CONFIRM" = "yes" ]; then
            echo "Adding SSH rule for 0.0.0.0/0..."

            aws ec2 authorize-security-group-ingress \
                --group-id $SECURITY_GROUP_ID \
                --protocol tcp \
                --port 22 \
                --cidr 0.0.0.0/0 \
                --region $REGION

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ SSH rule added${NC}"
                echo -e "${YELLOW}⚠ Remember to restrict this later!${NC}"
            else
                echo -e "${RED}✗ Failed to add SSH rule${NC}"
            fi
        fi
    else
        echo "Manual fix instructions:"
        echo "  1. Go to: https://console.aws.amazon.com/ec2/v2/home?region=$REGION#SecurityGroups:"
        echo "  2. Find security group: $SECURITY_GROUP_ID"
        echo "  3. Edit inbound rules"
        echo "  4. Add rule: Type=SSH, Port=22, Source=My IP"
        echo "  5. Save rules"
    fi
else
    echo -e "${BLUE}Step 5: Security group check${NC}"
    echo -e "${GREEN}✓ Security group appears to be configured${NC}"
fi

echo ""

# =============================================================================
# Step 6: Test SSH Connection
# =============================================================================
echo -e "${BLUE}Step 6: Testing SSH connection...${NC}"
echo ""

echo "Attempting SSH connection to $EC2_IP..."
echo "Command: ssh -i $KEY_PATH ec2-user@$EC2_IP"
echo ""

# Wait a moment for security group changes to propagate
if [ "$PORT_BLOCKED" = true ]; then
    echo "Waiting 10 seconds for security group changes to propagate..."
    sleep 10
    echo ""
fi

# Try SSH with timeout
if timeout 10 ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ec2-user@$EC2_IP "echo 'SSH connection successful!'" 2>&1; then
    echo ""
    echo -e "${GREEN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   ✓ SSH CONNECTION SUCCESSFUL!                       ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo "You can now connect with:"
    echo "  ssh -i $KEY_PATH ec2-user@$EC2_IP"
    echo ""

    echo "Next steps for Paper 1 ARM data:"
    echo "  1. Clone gravisonde repo on EC2"
    echo "  2. Copy Paper 1 videos to EC2"
    echo "  3. Run benchmarks on Graviton4"
    echo ""
    echo "See HYBRID_APPROACH_STATUS.md for detailed instructions"

else
    echo ""
    echo -e "${RED}✗ SSH connection failed${NC}"
    echo ""
    echo "Possible issues:"
    echo "  1. Security group changes may take 1-2 minutes to propagate"
    echo "  2. Instance may be in a different VPC/subnet"
    echo "  3. Network ACLs may be blocking traffic"
    echo "  4. Wrong SSH key"
    echo ""
    echo "Try again in 2 minutes:"
    echo "  ssh -i $KEY_PATH ec2-user@$EC2_IP"
    echo ""
    echo "Or check AWS Console:"
    echo "  https://console.aws.amazon.com/ec2/v2/home?region=$REGION#Instances:"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Instance: $INSTANCE_ID"
echo "IP: $EC2_IP"
echo "State: $INSTANCE_STATE"
echo "Security Group: $SECURITY_GROUP_ID"
echo ""
echo "SSH command:"
echo "  ssh -i $KEY_PATH ec2-user@$EC2_IP"
echo ""
