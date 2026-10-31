git remote set-url origin git@github.com:holyaustin/gravisonde.git
Successfully initiated launch of instance (i-0b0b534bf1c3e6d97)
ssh -i ~/.ssh/gravisonde-aws-key ec2-user@16.16.75.56

scp -i ~/.ssh/gravisonde-aws-key1 sample_video.mp4 ec2-user@16.16.75.56:~/data/sample1.mp4