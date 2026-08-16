# AUV Parameter Source Documentation (Qiao & Zhang 2019 / Ref [43])

This document details the physical, hydrodynamic, inertia, and geometric parameters of the fully actuated 6-DOF AUV adopted in Paper 1608 from Reference [43] (*IEEE Journal of Oceanic Engineering, 44(2), 2019, pp. 363-385*).

---

## 1. Physical and Geometrical Constants

| Parameter | Symbol | Value | Unit | Description |
| :--- | :--- | :---: | :---: | :--- |
| Mass | $m$ | $18.5$ | kg | Total AUV mass |
| Length | $L$ | $1.2$ | m | Total AUV length |
| Gravity | $g$ | $9.81$ | $\text{m/s}^2$ | Acceleration of gravity |
| Fluid density | $\rho$ | $1000$ | $\text{kg/m}^3$ | Water density |
| Buoyancy | $W = B_u$ | $m \cdot g = 181.485$ | N | Weight and buoyancy for neutrally buoyant AUV |
| CG Position | $[x_g, y_g, z_g]$ | $[0, 0, 0.01]^T$ | m | Center of gravity in body frame |
| CB Position | $[x_b, y_b, z_b]$ | $[0, 0, 0]^T$ | m | Center of buoyancy in body frame |

---

## 2. Moments of Inertia and Added Mass Parameters

### Nominal Inertia Matrix $M_{RB}$
$$I_x = 0.23, \quad I_y = 0.85, \quad I_z = 0.85 \quad (\text{kg}\cdot\text{m}^2)$$

### Added Mass Coefficient Matrix $M_A$
$$X_{\dot{u}} = -1.23, \quad Y_{\dot{v}} = -2.4, \quad Z_{\dot{w}} = -2.4 \quad (\text{kg})$$
$$K_{\dot{p}} = -0.04, \quad M_{\dot{q}} = -0.21, \quad N_{\dot{r}} = -0.21 \quad (\text{kg}\cdot\text{m}^2)$$

Total Nominal Mass Matrix $M = M_{RB} + M_A$:
$$M = \text{diag}\{m - X_{\dot{u}}, m - Y_{\dot{v}}, m - Z_{\dot{w}}, I_x - K_{\dot{p}}, I_y - M_{\dot{q}}, I_z - N_{\dot{r}}\}$$
$$M = \text{diag}\{19.73, 20.90, 20.90, 0.27, 1.06, 1.06\}$$

---

## 3. Hydrodynamic Damping Parameters

### Linear Damping Coefficients $D_L$
$$X_u = -1.62, \quad Y_v = -13.1, \quad Z_w = -13.1 \quad (\text{kg/s})$$
$$K_p = -0.15, \quad M_q = -0.68, \quad N_r = -0.68 \quad (\text{kg}\cdot\text{m}^2/\text{s})$$

### Nonlinear (Quadratic) Damping Coefficients $D_n(v)$
$$X_{u|u|} = -2.85, \quad Y_{v|v|} = -17.8, \quad Z_{w|w|} = -17.8 \quad (\text{kg/m})$$
$$K_{p|p|} = -0.008, \quad M_{q|q|} = -0.22, \quad N_{r|r|} = -0.22 \quad (\text{kg}\cdot\text{m}^2)$$
