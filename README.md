# CNN Accelerator – RTL to GDSII (Sky130)

## Overview
This project implements a CNN-based hardware accelerator designed in SystemVerilog and taken through a complete RTL-to-GDSII ASIC flow using OpenLane (Sky130 PDK).

The accelerator includes:

- Image Preprocessing
- Convolution Engine (MAC-based)
- ReLU Activation
- Max Pooling
- Fully Connected Layer
- AXI-Stream Interface
- Wrapper for Physical Design Integration

---

## ASIC Implementation Flow

Technology: Sky130  
Flow: OpenLane Automated RTL-to-GDSII  

Completed Stages:
- RTL Design
- Functional Verification
- Synthesis
- Floorplanning
- Placement
- Clock Tree Synthesis (CTS)
- Routing
- Static Timing Analysis
- DRC & LVS Signoff
- Final GDSII Generation

---

## Key Learning Outcomes

- Hardware dataflow optimization
- AXI protocol integration
- Power-Performance-Area trade-offs
- Backend physical design constraints
- Bridging algorithm to silicon implementation

---

## Final Outputs

- GDSII Layout
- LEF File
- Gate-level Netlist
- Timing Reports
- Power Reports

---

Author: Kudum Yashwanth
