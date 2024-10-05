#!/bin/bash
#SBATCH --job-name=llama-405b
#SBATCH --account=root
#SBATCH --partition=batch
#SBATCH --nodes=3
#SBATCH --nodelist=mk-xii-12,mk-xii-13,mk-xii-02                 # TODO: set to your nodenames
#SBATCH --gres=gpu:8
#SBATCH --cpus-per-task=19
#SBATCH --time=2000:00:00
#SBATCH --output=/home/simarora/utils/slurm_logs/slurm-%j.out    # TODO: make your own directory
#SBATCH --error=/home/simarora/utils/slurm_logs/slurm-%j.err

# Initialize HPC-X toolkit for high-performance computing
. /opt/hpcx/hpcx-init.sh
hpcx_load

export NCCL_IGNORE_CPU_AFFINITY=1  # Ignore CPU affinity settings
export TORCH_NCCL_ASYNC_ERROR_HANDLING=1  # Enable asynchronous error handling for PyTorch NCCL
export CUDA_DEVICE_ORDER=PCI_BUS_ID  # Set CUDA device order to PCI bus ID
export NCCL_IB_DISABLE=0  # Enable InfiniBand if available
export NCCL_NET_GDR_LEVEL=5  # Enable GPUDirect RDMA for faster GPU-to-GPU communication
export NCCL_P2P_DISABLE=0  # Enable peer-to-peer communication between GPUs
export NCCL_BUFFSIZE=2097152  # Set 2MB buffer size for NCCL operations
export NCCL_IB_HCA=mlx5  # Specify the InfiniBand Host Channel Adapter to use

export MASTER_HOSTNAME="mk-xii-13"                         # TODO: set to your nodenames
export MASTER_ADDR=$(host $MASTER_HOSTNAME | awk '/has address/ { print $4 }')
export MASTER_PORT=29500

export PYTHONPATH=/home/simarora/code/lolcats/             # TODO: Change to your path to lolcats repo location.

# Stage 1: Attention distillation. ( TODO: change the distill_llama_finetune.py hardcoded path to your own. )
# srun  torchrun --nnodes 3 --node_rank $SLURM_NODEID --rdzv_id $RANDOM --rdzv_backend c10d --rdzv_endpoint $MASTER_ADDR:$MASTER_PORT --nproc_per_node 8 /home/simarora/code/lolcats/llama_recipes/distill_llama.py \
#     --model_config llama3_1_405b/distill_llama3_1_405b_lk_smd_wtk64_fd64_w01 \
#     --distill_config llama3_1_405b/distill_llama_405b_xent1_mse1000_lr1e-2 \
#     --finetune_config llama3_1_405b/finetune_llama_405b \
#     --eval_config eval_alpaca_clean \
#     --verbose --replicate 0 --seed 0 \
#     --lk_zero_init --eval_steps 8 \
#     --dataset_chunk_size 512 \
#     --enable_fsdp --fsdp_activation_checkpointing 

# /home/simarora/code/lolcats/checkpoints/llama3_1_405b/distill_llama3_1_405b_lk_smd_wtk64_fd64_w01/distill-dl-d=llama3_1_405b/distill_llama_405b_xent0_mse1000_lr1e-3-m=llama3_1_405b/distill_llama3_1_405b_lk_smd_wtk64_fd64_w01-f=llama3_1_405b/finetune_llama_405b-fac=1-dcs=768-se=0-re=0-lzi=1

# Stage 2: LoRa end-to-end finetuning ( TODO: change the distill_llama_finetune.py hardcoded path to your own. )
srun  torchrun --nnodes 3 --node_rank $SLURM_NODEID --rdzv_id $RANDOM --rdzv_backend c10d --rdzv_endpoint $MASTER_ADDR:$MASTER_PORT --nproc_per_node 8 /home/simarora/code/lolcats/llama_recipes/distill_llama_finetune.py \
    --model_config llama3_1_405b/distill_llama3_1_405b_lk_smd_wtk64_fd64_w01 \
    --distill_config llama3_1_405b/distill_llama_405b_xent0_mse1000_lr1e-3 \
    --finetune_config llama3_1_405b/finetune_llama_405b \
    --eval_config eval_alpaca_clean \
    --verbose --replicate 0 --seed 0 \
    --lk_zero_init --eval_steps 8 \
    --dataset_chunk_size 768 \
    --enable_fsdp --fsdp_activation_checkpointing
