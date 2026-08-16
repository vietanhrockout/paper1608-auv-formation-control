# Paper 1608 Notation to MATLAB Variable Mapping Table

This document provides an explicit, unambiguous mapping between the LaTeX mathematical symbols used in Paper 1608 (*Neurocomputing, 2026, 133031*) and their corresponding MATLAB variable names, dimensions, and definitions.

---

## 1. System States & Kinematics / Dynamics Variables

| Paper Notation | MATLAB Variable Name | Dimension | Physical Meaning / Description | Reference Equation |
| :--- | :--- | :---: | :--- | :--- |
| $\eta_i$ | `eta(:,i)` | $6 \times 1$ | Position and attitude vector in Earth-fixed frame $[x, y, z, \phi, \theta, \psi]^T$ | Eq. (1) |
| $\dot{\eta}_i$ | `eta_dot(:,i)` | $6 \times 1$ | Velocity and angular velocity in Earth-fixed frame | Eq. (1) |
| $\nu_i$ | `nu(:,i)` | $6 \times 1$ | Body-fixed velocity vector $[u, v, w, p, q, r]^T$ | Eq. (1) |
| $J(\eta_i)$ | `J` | $6 \times 6$ | Jacobian transformation matrix from Body to Earth frame | Eq. (1) |
| $\dot{J}(\eta_i)$ | `Jdot` | $6 \times 6$ | Time derivative of Jacobian transformation matrix | Section 2 |
| $M_{0i}$ | `M0` | $6 \times 6$ | Nominal inertia coefficient matrix | Eq. (2) |
| $C_i(\eta_i, \dot{\eta}_i)$ | `C0` | $6 \times 6$ | Nominal Coriolis-centripetal matrix | Eq. (2) |
| $D_i(\eta_i, \dot{\eta}_i)$ | `D0` | $6 \times 6$ | Nominal hydrodynamic damping matrix | Eq. (2) |
| $g_i(\eta_i)$ | `g0` | $6 \times 1$ | Nominal restoring force vector (gravity & buoyancy) | Eq. (2) |
| $f_i(\eta_i, \dot{\eta}_i)$ | `f_true(:,i)` | $6 \times 1$ | True unknown drift dynamics $-M_{0i}^{-1}(C_i\dot{\eta}_i + D_i\dot{\eta}_i + g_i)$ | Eq. (7) |
| $\tau_{li}, d_i$ | `tau_d(:,i)`, `d_dist(:,i)` | $6 \times 1$ | External ocean current disturbance & lumped disturbance $d_i = M_{0i}^{-1}\tau_{li}$ | Eq. (2), (7), (55) |

---

## 2. Formation Trajectory & Tracking Error Variables

| Paper Notation | MATLAB Variable Name | Dimension | Physical Meaning / Description | Reference Equation |
| :--- | :--- | :---: | :--- | :--- |
| $\eta_{d0}$ | `eta_d0` | $6 \times 1$ | Virtual Leader spatial trajectory $[\sin(0.1t), -0.1t, -0.2t, -10, 0, 0]^T$ | Eq. (57) |
| $\dot{\eta}_{d0}, \ddot{\eta}_{d0}$ | `eta_d0_dot`, `eta_d0_ddot` | $6 \times 1$ | Virtual Leader trajectory velocity and acceleration | Eq. (7), (57) |
| $\eta_{l0i}$ | `eta_l0(:,i)` | $6 \times 1$ | Formation geometric offsets ($\text{AUV}_1: [3,4,2,0,0,0]^T$, $\text{AUV}_2: [6,1,4,0,0,0]^T$) | Eq. (5), (57) |
| $\bar{\eta}_{d0}$ | `eta_ref(:,i)` | $6 \times 1$ | Desired reference trajectory for $i$-th AUV ($\eta_{d0} + \eta_{l0i}$) | Section 3 |
| $\chi_i$ | `chi(:,i)` | $6 \times 1$ | Formation position tracking error vector ($\eta_i - \eta_{d0} - \eta_{l0i}$) | Eq. (5) |
| $\upsilon_i$ | `vel_err(:,i)` | $6 \times 1$ | Formation velocity tracking error vector ($\dot{\eta}_i - \dot{\bar{\eta}}_{d0}$) | Eq. (6) |

---

## 3. Sliding Surface & Anti-Windup Variables

| Paper Notation | MATLAB Variable Name | Dimension | Physical Meaning / Description | Reference Equation |
| :--- | :--- | :---: | :--- | :--- |
| $s_i$ | `s(:,i)` | $6 \times 1$ | Predefined-time nonsingular terminal sliding surface vector | Eq. (21) |
| $L(\chi_i)$ | `L_chi` | $6 \times 6$ | Diagonal matrix with gain elements $l_{\chi ij} = (a_1 |\chi_{ij}|^{\alpha_2} + a_2 |\chi_{ij}|^{\alpha_3})^{c\alpha_1}$ | Eq. (21) |
| $\tilde{L}(\chi_i)$ | `Ltilde_chi` | $6 \times 6$ | Derivative diagonal matrix derived from $l_{\chi ij}$ chain rule | Eq. (24) |
| $\Lambda_1$ | `Lambda1` | $6 \times 6$ | Diagonal matrix $\text{diag}\{ |\upsilon_{ij}|^{\alpha_1 - 1} \}$ | Eq. (24) |
| $\varpi_i$ | `omega_aw(:,i)` | $6 \times 1$ | Adaptive anti-windup auxiliary compensator state vector | Eq. (30) |
| $\tau_i$ | `tau_cmd(:,i)` | $6 \times 1$ | Designed nominal control command force/torque vector | Eq. (31) |
| $\text{sat}(\tau_{ui})$ | `tau_act(:,i)` | $6 \times 1$ | Actual saturated control force/torque applied to AUV | Eq. (3), (31) |
| $\Delta\tau_i$ | `delta_tau(:,i)` | $6 \times 1$ | Actuator saturation deviation vector ($\tau_{\text{act}} - \tau_{\text{cmd}}$) | Eq. (3), (30) |

---

## 4. Reinforcement Learning (Actor-Critic RBF NNs) Variables

| Paper Notation | MATLAB Variable Name | Dimension | Physical Meaning / Description | Reference Equation |
| :--- | :--- | :---: | :--- | :--- |
| $\theta_c(\eta_i)$ | `theta_c` | $m_c \times 1$ | Gaussian RBF basis functions vector for Critic NN | Eq. (14), (17) |
| $\hat{C}_i(t)$ | `C_hat(i)` | Scalar | Estimated long-term cumulative execution cost (cost-to-go) | Eq. (17) |
| $\hat{w}_c$ | `Wc(:,i)` | $m_c \times 1$ | Weight vector of Critic NN | Eq. (17), (20) |
| $\Phi$ | `Phi_critic` | $m_c \times 1$ | Critic regressor vector $-\frac{\theta_c}{\lambda} + \nabla\theta_c \upsilon_i$ | Eq. (19) |
| $\Phi_c$ | `Phi_c_update` | $m_c \times 1$ | Critic update gradient $(r(t) + \hat{w}_c^T \Phi) \Phi$ | Eq. (19) |
| $\theta_{aij}(\bar{x}_{aij})$ | `theta_a(:,j,i)` | $m_a \times 1$ | Gaussian RBF basis vector for Actor NN ($j$-th DOF of $i$-th AUV) | Eq. (14), (32) |
| $\bar{x}_{aij}$ | `x_actor(:,j,i)` | $2 \times 1$ | Input vector to Actor NN $[\chi_{ij}, \upsilon_{ij}]^T$ | Eq. (32) |
| $f_{iRL}$ | `f_rl(:,i)` | $6 \times 1$ | Actor NN estimated unknown drift dynamics output vector | Eq. (32) |
| $\hat{w}_{aij}$ | `Wa(:,j,i)` | $m_a \times 1$ | Weight vector of Actor NN ($j$-th DOF of $i$-th AUV) | Eq. (32), (38) |
| $\delta_c, \delta_a$ | `delta_c`, `delta_a` | Vectors | Weight projection upper bounds for Critic and Actor NNs | Eq. (20), (38) |
| $r(t)$ | `r_cost` | Scalar | Immediate execution cost function $\chi_i^T B \chi_i + \tau_i^T R \tau_i$ | Eq. (16) |

---

## 5. Standard Reserved Variables Protocol

The following variable names are **STRICTLY RESERVED** and MUST NOT be used for arbitrary temporary variables without qualification:
- `eta`, `eta_dot`, `nu`: Physical AUV state vectors.
- `chi`, `vel_err`: Tracking error vectors.
- `s`, `omega_aw`: Sliding surface and anti-windup state vectors.
- `tau_cmd`, `tau_act`, `delta_tau`: Control effort vectors.
- `f_true`, `f_rl`: True dynamic drift vs RL approximation vectors.
- `C_hat`, `Wc`, `Wa`: Critic estimated cost and NN weight matrices.
