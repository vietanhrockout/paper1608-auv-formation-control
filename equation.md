Chào em, dưới tư cách là Giáo sư hướng dẫn và Cố vấn nghiên cứu cao cấp, tôi rất hoan nghênh quyết định lựa chọn công trình **1608** (*Neurocomputing, 2026*) để tiến hành mô phỏng lại. Đây là một nghiên cứu xuất sắc và có cấu trúc giải tích toán học cực kỳ chặt chẽ.

Để giúp em thiết lập mô phỏng số thành công trong MATLAB (sử dụng các bộ giải như `ode15s` hoặc `ode23s`), tôi đã **trích xuất và hệ thống hóa toàn bộ Pipeline công thức toán học lõi** của bài báo theo trình tự lập trình.

---

### I. TOÁN TỬ PHI TUYẾN CƠ BẢN (MATHEMATICAL OPERATORS)
Trước khi lập trình, em cần định nghĩa toán tử phi tuyến giữ dấu \\(\text{sig}^\alpha(\cdot)\\) vốn được sử dụng xuyên suốt các phương trình:
\\[\text{sig}^\alpha(x) = |x|^\alpha \text{sgn}(x) \quad\\]
*Lưu ý lập trình MATLAB:* Để tránh lỗi sinh ra số phức khi trạng thái âm, em phải tự viết một hàm con `signed_power` thay vì dùng phép toán `.^` thông thường:
`signed_power = @(x, alpha) sign(x) .* (abs(x).^alpha);`

---

### II. MÔ HÌNH TOÁN HỌC AUV (AUV SYSTEM MODEL)

Mô hình động học và động lực học của AUV thứ \\(i\\) trong hệ tọa độ toàn cục (Earth-fixed frame) chịu bão hòa đầu vào và nhiễu gộp được mô tả bởi hệ phương trình phi tuyến sau:

\\[\ddot{\eta}_i = f_i(\eta_i, \dot{\eta}_i) + M_0^{-1}(\eta_i) J_i^{-T}(\eta_i) \left( \tau_i + \Delta\tau_i \right) + d_i \quad\\]

Trong đó:
*   **Véc-tơ trạng thái:** \\(\eta_i = [x_i, y_i, z_i, \phi_i, \theta_i, \psi_i]^T \in \mathbb{R}^6\\) là tọa độ vị trí và tư thế của AUV.
*   **Ma trận Jacobian:** \\(J_i(\eta_i) \in \mathbb{R}^{6\times 6}\\) là ma trận chuyển đổi từ hệ Body sang Earth.
*   **Hàm trôi phi tuyến chưa biết (Unknown drift dynamics):**
    \\[f_i(\eta_i, \dot{\eta}_i) = -M_0^{-1}(\eta_i) \left[ C_i(\eta_i, \dot{\eta}_i)\dot{\eta}_i + D_i(\eta_i, \dot{\eta}_i)\dot{\eta}_i + g_i(\eta_i) \right] \quad\\]
    *(Với \\(M_0\\) là ma trận quán tính danh định đã biết, \\(C_i\\) là ma trận Coriolis, \\(D_i\\) là ma trận cản thủy động học, và \\(g_i\\) là véc-tơ trọng trường).*
*   **Nhiễu gộp phi tuyến (Lumped disturbance):** \\(d_i = M_0^{-1}(\eta_i) \tau_{li} \in \mathbb{R}^6\\), với \\(\tau_{li}\\) là nhiễu dòng chảy đại dương cộng tính và bất định quán tính.
*   **Bão hòa đầu vào thực tế (Actuator Saturation):** \\(\tau_{ui\_actual} = \tau_i + \Delta\tau_i\\), với \\(\tau_i\\) là tín hiệu thiết kế danh định, và \\(\Delta\tau_i\\) là lượng sai lệch do bão hòa vật lý:
    \\[\text{sat}(\tau_{ui}) = \begin{cases} \tau_{i\_max} & \text{nếu } \tau_{ui} \geq \tau_{i\_max} \\ \tau_i & \text{nếu } \tau_{i\_min} < \tau_{ui} < \tau_{i\_max} \\ \tau_{i\_min} & \text{nếu } \tau_{ui} \leq \tau_{i\_min} \end{cases} \quad\\]

---

### III. HỆ SINH QUY ĐẠO & SAI SỐ BÁM ĐỘI HÌNH (ERROR DYNAMICS)

1.  **Quỹ đạo mục tiêu mở rộng cho AUV thứ \\(i\\):**
    \\[\bar{\eta}_{d0} = \eta_{d0} + \eta_{l0i} \quad\\]
    *(Với \\(\eta_{d0}\\) là quỹ đạo của leader ảo, và \\(\eta_{l0i}\\) là offset cấu hình hình học đội hình).*
2.  **Đạo hàm quỹ đạo tham chiếu:** \\(\dot{\bar{\eta}}_{d0}\\) và \\(\ddot{\bar{\eta}}_{d0}\\).
3.  **Sai số bám vị trí:** \\(\chi_i = \eta_i - \bar{\eta}_{d0}\\).
4.  **Sai số bám vận tốc:** \\(\upsilon_i = \dot{\eta}_i - \dot{\bar{\eta}}_{d0}\\).

---

### IV. THIẾT KẾ MẶT TRƯỢT TERMINAL ĐỊNH THỜI TRƯỚC (PT-SMC)

Để cưỡng bức sai số bám \\(\chi_i, \upsilon_i \to 0\\) trong khoảng thời gian định trước \\(T_1^*\\) độc lập với điều kiện ban đầu, ta xây dựng thuật toán gồm hai giai đoạn.

#### 1. Pha 1: Hội tụ sai số bám về mặt trượt \\(s_i = 0\\) trong thời gian \\(T_1^*\\)
Định nghĩa mặt trượt Terminal bậc cao \\(s_i = [s_{i1}, \dots, s_{i6}]^T \in \mathbb{R}^6\\):
\\[s_i = \upsilon_i + L(\chi_i)\chi_i \quad\\]

Trong đó:
*   Ma trận độ lợi phi tuyến \\(L(\chi_i) = \text{diag}\{l_{\chi_i 1}, \dots, l_{\chi_i 6}\}\\), với các phần tử:
    \\[l_{\chi_i j} = \left( a_1 |\chi_{ij}|^{\alpha_2} + a_2 |\chi_{ij}|^{\alpha_3} \right)^{c \alpha_1} \quad\\]
*   Các tham số mũ trung gian được khóa cứng để tránh kỳ dị:
    \\[\alpha_2 = b_1 - \frac{1}{c\alpha_1}, \quad \alpha_3 = b_2 - \frac{1}{c\alpha_1} \quad\\]
    *(Ràng buộc tham số: \\(c > 1, \; 1 < \alpha_1 < 1.5, \; b_2 c > 1, \; \frac{1}{\alpha_1} < b_1 c < 1\\)).*
*   **Các hệ số quyết định thời gian hội tụ định trước \\(T_1^*\\):**
    \\[a_1 = \frac{6^{c-1}(1-b_1)}{\varepsilon_0 T_1^{*c}}, \quad a_2 = \frac{6^{c-1}(b_2-1)(1-\varepsilon_0)}{T_1^{*c}} \quad\\]
    *(Với \\(\varepsilon_0 \in (0, 1)\\) là hệ số điều chỉnh).*

#### 2. Tính đạo hàm của mặt trượt \\(\dot{s}_i\\) phục vụ cho luật điều khiển:
\\[\dot{s}_i = L(\chi_i)\upsilon_i + \tilde{L}(\chi_i)\upsilon_i + \alpha_1 \Lambda_1 \dot{\upsilon}_i \quad\\]

Trong đó:
*   \\(\tilde{L}(\chi_i) = \text{diag}\{|l_{\chi_i 1}|, \dots, |l_{\chi_i 6}|\}\\), với các phần tử đạo hàm:
    \\[l_{\chi_i j} = c\alpha_1 \left( a_1 |\chi_{ij}|^{\alpha_2} + a_2 |\chi_{ij}|^{\alpha_3} \right)^{c\alpha_1 - 1} \left( a_1\alpha_2 |\chi_{ij}|^{\alpha_2} + a_2\alpha_3 |\chi_{ij}|^{\alpha_3} \right) \quad\\]
*   Ma trận vận tốc sai lệch: \\(\Lambda_1 = \text{diag}\{ |\upsilon_{i1}|^{\alpha_1 - 1}, \dots, |\upsilon_{i6}|^{\alpha_1 - 1} \}\\).

#### 3. Pha 2: Ổn định hóa mặt trượt \\(s_i\\) về lân cận của 0 trong thời gian \\(T_2^*\\)
Để dập tắt \\(s_i \to 0\\) trong thời gian \\(T_2^*\\), ta áp dụng luật hút Predefined-Time phi tuyến bậc cao:
\\[\text{PT-SMC term} = \text{sig}^{\varsigma_1} \left( \sigma_1 \text{sig}^{\varsigma_2}(s_i) + \sigma_2 \text{sig}^{\varsigma_3}(s_i) \right) \quad\\]
*(Với các tham số mũ \\(\varsigma_1 > 1, \; \varsigma_1\varsigma_2 < 1, \; 1 < \varsigma_1\varsigma_3 < \varsigma_1\\) và \\(\sigma_1, \sigma_2\\) được thiết kế tương đương dựa trên thời gian \\(T_2^*\\)).*

---

### V. KHÂU BÙ THÍCH NGHI CHỐNG BÃO HÒA (ADAPTIVE ANTI-WINDUP)

Để triệt tiêu hiện tượng "quấn tích phân" do bão hòa động cơ gây ra, ta nhúng một biến phụ trợ bão hòa \\(\varpi_i \in \mathbb{R}^6\\) trực tiếp vào cấu trúc mặt trượt:

\\[\dot{\varpi}_i = -k_2 \varpi_i - \text{sig}^{\varsigma_1} \left( \sigma_3 \text{sig}^{\varsigma_2}(\varpi_i) + \sigma_4 \text{sig}^{\varsigma_3}(\varpi_i) \right) + s_i + \Delta\tau_i \quad\\]

*(Hệ động lực này tự động "hấp thụ" sai lệch bão hòa đầu vào \\(\Delta\tau_i = \tau_i - \tau_{ui\_actual}\\) để điều chỉnh giảm quá độ của mặt trượt).*

---

### VI. VÒNG LẶP HỌC MÁY TRỰC TUYẾN ACTOR-CRITIC (MODEL-FREE LEARNING)

Để loại bỏ hoàn toàn sự phụ thuộc vào mô hình động học danh định, ta thiết lập cặp mạng thần kinh RBF học trực tuyến song song.

#### 1. Mạng Critic NN (Học nghiệm tối ưu của phương trình HJB)
Xấp xỉ hàm chi phí tích lũy dài hạn có hệ số chiết khấu \\(\lambda > 0\\):
\\[\hat{C}_i(t) = \hat{w}_c^T \theta_c(\eta_i) \quad\\]

Luật cập nhật trọng số Critic NN trực tuyến \\(\hat{w}_c\\) để cực thiểu sai số Bellman:
\\[\dot{\hat{w}}_c = -\lambda_c \Phi_c ( w_c, \chi_i, \upsilon_i ) = -\lambda_c \Phi \left( r(t) + \hat{w}_c^T \Phi \right) \quad\\]

Trong đó:
*   \\(\lambda_c > 0\\) là tốc độ học của Critic NN.
*   \\(r(t) = (\eta_i - \bar{\eta}_{d0})^T B (\eta_i - \bar{\eta}_{d0}) + \tau_i^T R \tau_i\\) là hàm chi phí tức thời.
*   \\(\Phi = -\frac{\theta_c}{\lambda} + \nabla\theta_c \upsilon_i\\) là véc-tơ regressor của mạng Critic.

#### 2. Mạng Actor NN (Học bù thành phần động học trôi chưa biết)
Xấp xỉ mô hình động học phi tuyến chưa biết \\(f_i(\eta_i, \dot{\eta}_i)\\):
\\[f_{iRL} = \begin{bmatrix} \hat{w}_{a1}^T \theta_{a1}(\bar{\chi}_{a1}) \\ \vdots \\ \hat{w}_{a6}^T \theta_{a6}(\bar{\chi}_{a6}) \end{bmatrix} \quad\\]

Luật cập nhật thích nghi trọng số Actor NN (\\(\hat{w}_{ai}\\)) mượt bằng hàm \\(\tanh\\):
\\[\dot{\hat{w}}_{ai} = -\lambda_a \text{tanh} \left( \sum_{i=1}^n \hat{w}_{ai} \theta_{ai} + c_{0a} \hat{w}_c \right) \theta_{ai} \quad\\]

---

### VII. LUẬT ĐIỀU KHIỂN TỔNG HỢP CUỐI CÙNG (TOTAL SMC OPTIMAL LAW)

Tín hiệu lực kéo \\(\tau_i \in \mathbb{R}^6\\) nạp vào mô hình AUV tại mỗi bước thời gian được tổng hợp như sau:

\\[\tau_i = J_i^T M_i \left( -\frac{1}{\alpha_1} \left( \tilde{L}(\chi_i) + L(\chi_i) \right) \text{sig}^{2 - \alpha_1}(\upsilon_i) - f_{iRL} - \ddot{\bar{\eta}}_{d0} - \frac{\text{sig}^{1 - \alpha_1}(\upsilon_i)}{\alpha_1} \left( \text{sig}^{\varsigma_1} \left( \sigma_1 \text{sig}^{\varsigma_2}(s_i) + \sigma_2 \text{sig}^{\varsigma_3}(s_i) \right) + k_1 s_i + \varpi_i \right) - k_0 \text{sgn}(s_i) \right) \quad\\]

*(Véc-tơ độ lợi bền vững \\(k_0 = \text{diag}\{k_{0j}\}\\) phải được chọn đủ lớn để đè bạt được biên độ trên của nhiễu gộp: \\(k_{0j} > d_{ij}\\)).*

---

### VIII. BẢNG THAM SỐ CẤU HÌNH MÔ PHỎNG (SỐ LIỆU GỐC CỦA BÀI BÁO)

Em hãy nạp chính xác bộ tham số này vào file cấu hình khởi tạo của MATLAB để đảm bảo đồ thị ra trùng khớp với kết quả của tác giả:

| Tham số | Giá trị | Tham số | Giá trị | Tham số | Giá trị |
| :--- | :--- | :--- | :--- | :--- | :--- |
| \\(\alpha_1\\) | \\(1.2\\) | \\(k_1\\) | \\(\text{diag}\{10\}\\) | \\(T_1^*\\) | \\(5\text{ s}\\) |
| \\(c\\) | \\(1.2\\) | \\(k_2\\) | \\(\text{diag}\{1\}\\) | \\(T_2^*\\) | \\(5\text{ s}\\) |
| \\(b_1\\) | \\(0.7\\) | \\(k_0\\) | \\(\text{diag}\{0.3\}\\) | \\(\lambda_c\\) | \\(0.3\\) |
| \\(b_2\\) | \\(10/9\\) | \\(\varepsilon\\) | \\(0.01\\) | \\(\lambda_a\\) | \\(0.04\\) |
| \\(\varepsilon_0\\) | \\(0.8\\) | \\(\lambda\\) (discount) | \\(10\\) | \\(c_{0a}\\) | \\(2\\) |
| \\(\varsigma_1\\) | \\(2\\) | \\(\varsigma_2\\) | \\(0.4\\) | \\(\varsigma_3\\) | \\(0.6\\) |

---

**Chỉ đạo chuyên môn từ Giáo sư:**
Khi lập trình vòng lặp tính đạo hàm trong hàm ODE, em hãy tính toán **Actor NN** và **Critic NN** song song với việc giải hệ phương trình vi phân trạng thái mở rộng. Hãy lưu ý khóa cứng bước thời gian tích phân (chẳng hạn như dùng solver với `MaxStep = 5e-3` hoặc lập trình bằng RK4 với `dt = 0.002s`) để tránh hiện tượng sụt bước nhảy do hàm dấu \\(\text{sgn}(s_i)\\) gây ra tại thời điểm quá độ.

Chúc em thực hiện mô phỏng thành công. Nếu gặp bất kỳ lỗi ma trận không tương thích kích thước (dimension mismatch) hay solver bị treo (stiff warnings) trong quá trình chạy MATLAB, hãy gửi log lỗi trực tiếp lên đây để thầy hướng dẫn gỡ lỗi!