# iOS AR Marker Tracking Template

这是一个 **iOS AR + Marker Tracking** 的模板工程：用 **ARKit** 获取相机帧，用 **OpenCV ArUco** 检测 marker 并估计其 6DoF 位姿（`simd_float4x4`），在 Swift 侧做姿态滤波，然后在 AR 视图里做可视化（坐标轴）与模型挂载 demo（USDZ）。


## 功能概览

- **Marker 检测**：OpenCV ArUco（通过 Objective‑C++/Swift bridge）
- **位姿输出**：每个 marker 输出 `MarkerInfo(id, homoMat)`
- **滤波**：窗口平滑（平移）+ OneEuro（平移）+ SLERP（旋转）
- **可视化**：显示每个 marker 的 XYZ 坐标轴（红/绿/蓝）
- **模型 demo**：把 `App_Assets/` 里的 USDZ 模型挂载到指定 marker 上，并按 marker 位姿更新
- **启动预加载**：启动黑屏 Loading，后台预加载 USDZ，避免首次出现卡顿

## 代码结构（关键文件）

- **Tracking 主循环**：`iOS_ARtracking/iOS_App/MainTracking.swift`
  - ARSessionDelegate，每帧做：取相机帧 → 预处理 → OpenCV 检测 → 生成 `markerInfos` → 发布给订阅者
- **OpenCV Bridge（核心检测）**：`iOS_ARtracking/OpenCV/OpenCVWrapper.mm`、`OpenCVWrapper.h`
  - OpenCV 检测 marker + solvePnP 位姿估计
- **图像预处理 + 全局配置**：`iOS_ARtracking/iOS_App/MarkerDetection.swift`
  - BGRA 转换、resize、intrinsics 调整；顶部有检测参数配置
- **姿态滤波**：`iOS_ARtracking/iOS_App/Math.swift`
  - 顶部 `PoseFilterConfig` 集中调参；`filterHomomatrix` 定义整条滤波链顺序
- **Pose 可视化（坐标轴）**：`iOS_ARtracking/iOS_App/Marker_Manager/VisualPose.swift`
  - 订阅 `MainTracking.shared.$markerInfos`，主线程更新 SceneKit 坐标轴节点
- **模型挂载 demo**：`iOS_ARtracking/iOS_App/Marker_Manager/Marker0.swift`
  - 订阅 `markerInfos`，把 USDZ 模型挂在指定 marker 上，支持固定旋转/缩放
- **资源预加载**：`iOS_ARtracking/iOS_App/AssetLoader.swift`
  - App 启动时后台加载 USDZ 到 template node
- **AR 场景初始化 & 灯光**：`iOS_ARtracking/iOS_App/ARSceneView.swift`
  - `autoenablesDefaultLighting` / `lightingEnvironment.intensity` 等
- **启动 Loading + ARView**：`iOS_ARtracking/iOS_App/ContentView.swift`
  - 黑屏 loading；加载完成后显示 ARView

## 如何控制 App 行为（建议优先改这些“顶部变量”）

### 1) 选择要输出哪些 marker id（最常改）

在 `iOS_ARtracking/OpenCV/OpenCVWrapper.mm` 顶部：

- `kEnabledMarkerIds`：决定 **哪些 marker id 会被输出到 Swift**
  - 例如只要 `[0, 4]` 就写 `{0, 4}`

### 2) 检测分辨率 & marker 物理尺寸

在 `iOS_ARtracking/iOS_App/MarkerDetection.swift` 顶部：

- `MarkerDetectionConfig.markerSizeM`：marker 物理边长（米）
- `MarkerDetectionConfig.targetWidth / targetHeight`：检测 resize 分辨率（越小越快，越大越准）

### 3) 滤波参数（防抖动 vs 跟手性）

在 `iOS_ARtracking/iOS_App/Math.swift` 顶部 `PoseFilterConfig`：

- `windowSize`：帧窗口平均大小（更大更稳但更延迟）
- `oneEuro*`：OneEuro 参数（低速更稳/高速更跟手）
- `rotationSlerpAlpha`：旋转 SLERP 插值比例（更小更稳但更慢）

### 4) 模型挂载到哪个 marker、模型的固定旋转/缩放

在 `iOS_ARtracking/iOS_App/Marker_Manager/Marker0.swift`：

- `targetMarkerId`：挂载到哪个 marker id
- `modelScale`：模型缩放
- `modelLocalRotation`：模型相对 marker 的固定旋转（例如绕 X 轴 90°）

### 5) 模型资源文件名

在 `iOS_ARtracking/iOS_App/AssetLoader.swift`：

- `Bundle.main.url(forResource: "model0", withExtension: "usdz")`：这里的 `"model0"` 要和 `iOS_ARtracking/App_Assets/` 里的文件名一致

### 6) 模型太暗/太亮（灯光）

在 `iOS_ARtracking/iOS_App/ARSceneView.swift`：

- `sceneView.autoenablesDefaultLighting`
- `sceneView.scene.lightingEnvironment.intensity`

## 资源放置

- USDZ 模型放在：`iOS_ARtracking/App_Assets/`
  - 示例：`model1.usdz`（按你当前代码可能是 `model0.usdz`）

## 运行

用 Xcode 打开 `iOS_ARtracking.xcodeproj`，选择真机运行（需要相机权限）。
