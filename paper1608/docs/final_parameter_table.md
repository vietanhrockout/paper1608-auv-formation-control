# Final Audited Parameter Table — Paper 1608 Reproduction

| Parameter | Symbol | Value | Unit / Description | Source & Audit Status |
|---|---|---|---|---|
| Sliding Power 1 | $\alpha_1$ | 1.2 | Exponent ($1 < \alpha_1 < 1.5$) | Table 1 (Audited PASS) |
| Predefined Time 1 | $T_1^*$ | 5.0 | seconds | Table 1 (Audited PASS) |
| Predefined Time 2 | $T_2^*$ | 5.0 | seconds | Table 1 (Audited PASS) |
| Reaching Exponent 1 | $\varsigma_1$ | 2.0 | Exponent ($\varsigma_1 > 1$) | Table 1 (Audited PASS) |
| Reaching Exponent 2 | $\varsigma_2$ | 0.4 | Exponent ($\varsigma_1\varsigma_2 < 1$) | Table 1 (Audited PASS) |
| Reaching Exponent 3 | $\varsigma_3$ | 0.6 | Exponent ($1 < \varsigma_1\varsigma_3 < \varsigma_1$) | Table 1 (Audited PASS) |
| Gain Factor | $c$ | 1.2 | Coefficient ($c > 1$) | Table 1 (Audited PASS) |
| Exponent Base 1 | $b_1$ | 0.7 | Coefficient ($1/\alpha_1 < b_1 c < 1$) | Table 1 (Audited PASS) |
| Exponent Base 2 | $b_2$ | $10/9 \approx 1.111$ | Coefficient ($b_2 c > 1$) | Table 1 (Audited PASS) |
| Fraction Factor | $\varepsilon_0$ | 0.8 | Coefficient ($0 < \varepsilon_0 < 1$) | Table 1 (Audited PASS) |
| Derived Exponent 1 | $\alpha_2$ | 0.005556 | $b_1 - 1/(c\alpha_1)$ | Formula Eq. (21) (Audited PASS) |
| Derived Exponent 2 | $\alpha_3$ | 0.416667 | $b_2 - 1/(c\alpha_1)$ | Formula Eq. (21) (Audited PASS) |
| Derived Coeff 1 (PDF Literal) | $a_1$ | 1.192474 | $6^{c-1}/((1-b_1)\varepsilon_0 T_2^*)$ | Formula Eq. (22) (Audited PASS) |
| Derived Coeff 2 (PDF Literal) | $a_2$ | 12.878722 | $6^{c-1}/((b_2-1)(1-\varepsilon_0) T_2^*)$ | Formula Eq. (22) (Audited PASS) |
| Reaching Gain 1 (PDF Literal) | $\sigma_1^{\text{literal}}$ | 0.454545 | Eq. (26) PDF text | Formula Eq. (26) (Audited PASS) |
| Reaching Gain 2 (PDF Literal) | $\sigma_2^{\text{literal}}$ | -2.222222 | Eq. (26) PDF text (Negative) | Formula Eq. (26) (Audited PASS - Negative) |
| Reaching Gain 1 (Sign Flip) | $\sigma_1^{\text{sign\_flip}}$ | 0.454545 | Empirical candidate | Formula Eq. (26) (Audited Candidate) |
| Reaching Gain 2 (Sign Flip) | $\sigma_2^{\text{sign\_flip}}$ | +2.222222 | Empirical candidate | Formula Eq. (26) (Audited Candidate) |
| Reaching Gain 1 (Simulation) | $\sigma_1^{\text{eq29}}$ | 2.835190 | Independent derivation from Eq. (29) | Formula Eq. (29) (Audited PASS - Positive) |
| Reaching Gain 2 (Simulation) | $\sigma_2^{\text{eq29}}$ | 5.290651 | Independent derivation from Eq. (29) | Formula Eq. (29) (Audited PASS - Positive) |
| Actor Learning Rate | $\lambda_a$ | 0.04 | Adaptation gain | Table 1 (Audited PASS) |
| Critic Learning Rate | $\lambda_c$ | 0.3 | Adaptation gain | Table 1 (Audited PASS) |
| Actor Error Weight Factor | $c_{0a}$ | 2.0 | Scaling factor | Table 1 (Audited PASS) |
| Discount Factor | $\lambda$ | 10.0 | Future cost discount | Table 1 (Audited PASS) |
| RBF Width Critic | $l_c$ | 5.0 | RBF Gaussian width | Table 1 (Audited PASS) |
| RBF Width Actor | $l_a$ | 5.0 | RBF Gaussian width | Table 1 (Audited PASS) |
| Robust Sliding Gain | $k_0$ | 0.3 | Matrix gain $0.3 I_6$ | Table 1 (Audited PASS) |
| Sliding Surface Gain | $k_1$ | 10.0 | Matrix gain $10 I_6$ | Table 1 (Audited PASS) |
| Anti-Windup Gains | $\sigma_3, \sigma_4$ | 8.0 | Predefined-time gains | Table 1 (Audited PASS) |
| Utility State Weight | $B$ | $I_6$ | Weighting matrix (Eq. 16) | ASSUMED ($B > 0$) |
| Utility Input Weight | $R$ | $10^{-4} I_6$ | Weighting matrix (Eq. 16) | ASSUMED ($R > 0$) |
| Actuator Max Force | $\tau_{\max,\text{force}}$ | 150.0 | N | ASSUMED / IMPLEMENTATION CONFIG |
| Actuator Max Torque | $\tau_{\max,\text{moment}}$ | 30.0 | N$\cdot$m | ASSUMED / IMPLEMENTATION CONFIG |
