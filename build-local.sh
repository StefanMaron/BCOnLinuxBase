#!/bin/bash

# Local build script that mimics the CI/CD two-stage process
# This builds the base image and then runs Wine initialization to create the final image

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BASE_IMAGE_NAME="bc-wine-base"
STAGE1_TAG="stage1"
FINAL_TAG="local"
CONTAINER_NAME="wine-init-local"
NO_CACHE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [--no-cache]"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}=== Building BC Wine Base Image Locally ===${NC}"
echo ""

# Pull latest base image
echo -e "${YELLOW}Pulling latest sshadows/wine-bc:latest base image...${NC}"
docker pull sshadows/wine-bc:latest
echo ""

# Step 1: Build the base image (without Wine initialization)
echo -e "${YELLOW}Step 1: Building base image...${NC}"
docker build ${NO_CACHE} -t ${BASE_IMAGE_NAME}:${STAGE1_TAG} .

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Base image build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Base image built successfully${NC}"
echo ""

# Step 2: Run Wine initialization in a container
echo -e "${YELLOW}Step 2: Running Wine initialization...${NC}"
echo "This will initialize Wine prefix and install BC Container Helper"

# Remove any existing container with the same name
docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

# Run the container to initialize Wine
docker run --name ${CONTAINER_NAME} ${BASE_IMAGE_NAME}:${STAGE1_TAG}

# Check if initialization was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Wine initialization completed successfully${NC}"
else
    echo -e "${RED}✗ Wine initialization failed${NC}"
    echo "Showing container logs:"
    docker logs ${CONTAINER_NAME}
    docker rm ${CONTAINER_NAME}
    exit 1
fi
echo ""

# Step 3: Commit the initialized container as the final image
echo -e "${YELLOW}Step 3: Creating final image from initialized container...${NC}"
docker commit ${CONTAINER_NAME} ${BASE_IMAGE_NAME}:${FINAL_TAG}

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to commit container as final image${NC}"
    docker rm ${CONTAINER_NAME}
    exit 1
fi
echo -e "${GREEN}✓ Final image created successfully${NC}"

# Clean up the container
docker rm ${CONTAINER_NAME}
echo ""

# Step 4: Test the final image
echo -e "${YELLOW}Step 4: Testing final image...${NC}"
docker run --rm ${BASE_IMAGE_NAME}:${FINAL_TAG} wine --version

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Wine is functional in final image${NC}"
else
    echo -e "${RED}✗ Wine test failed${NC}"
    exit 1
fi

# Show image information
echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo "Image: ${BASE_IMAGE_NAME}:${FINAL_TAG}"
echo "Size: $(docker images ${BASE_IMAGE_NAME}:${FINAL_TAG} --format "{{.Size}}")"
echo ""
echo "To use the image:"
echo "  docker run --rm -it ${BASE_IMAGE_NAME}:${FINAL_TAG} /bin/bash"
echo ""
echo "To test Wine and BC environment:"
echo "  docker run --rm ${BASE_IMAGE_NAME}:${FINAL_TAG} /usr/local/bin/test-wine.sh"
echo ""
echo "To check BC Container Helper:"
echo "  docker run --rm ${BASE_IMAGE_NAME}:${FINAL_TAG} pwsh -c 'Get-Module -ListAvailable BcContainerHelper'"