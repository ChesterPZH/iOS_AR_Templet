# iOS AR project template #

待办：原来这个项目是针对于用apple pencil书写的，我们要把它先退回到只acquire每个marker的3D pose就行。
原项目参考下面视频
https://www.youtube.com/watch?v=zoM2F_kCsGM

我在develop的过程中有一个stage就是visualize 6个 marker 的 3D pose，如下图所示。以回到渲染这个可视化阶段为目标。
![demo](demo.jpg) 

以下是`maintrakcing.swift`的主体部分，也就是管理整体渲染runtime的file。I believe `VisualContent.shared.drawAxesForMarkers` 就是draw上述axis的funtion。因此我们只需要找一个render功能，可以清除所有和绘画，apple pencil管理的files。
I believe`ContentView.swift`, `Math.swift`, `PencilManager.swift`, `StrokeManager.swift`, `VirtualPencilModel.swift`, `VisualContent.swift` 都有需要删减的内容
```swift
            // Calculate average tip position
            let avgMatrix = VirtualPencilModel.shared.calculateAverageTip(markerInfos: markerInfos)
            
            // Process tip position with filtering
            var tipFiltered: simd_float3? = nil
            var tipVec: simd_float3? = nil
            if let avgMatrix = avgMatrix {
                tipVec = Math.homoMatToTipVec(avgMatrix)
            }
            if let tipVec = tipVec {
                let smoothed = Math.smoothTipVec(tipVec)  // Apply smoothing
                let oneEuroFiltered = Math.oneEuroFilter(smoothed, minCutoff: 2.0, beta: 0.5, dCutoff: 2.0)  // Apply OneEuro filter
                tipFiltered = Math.jumpFilter(oneEuroFiltered)  // Apply jump filtering
            }

            // Update UI in main thread
            DispatchQueue.main.async {
                self.markerInfos = markerInfos
                if markerInfos.isEmpty {
                    // No markers detected
                    VisualContent.shared.renderTip(nil)
                    VisualContent.shared.drawAxesForMarkers(markerInfos: [])
                    // Use last valid tip position
                    if let lastTip = self.lastTipFiltered {
                        StrokeManager.shared.updateTip(lastTip, in: frame.camera.transform)
                    }
                } else {
                    // Update visualizations and stroke
                    VisualContent.shared.renderTip(tipFiltered)
                    VisualContent.shared.drawAxesForMarkers(markerInfos: markerInfos)
                    StrokeManager.shared.updateTip(tipFiltered, in: frame.camera.transform)
                    // Update last valid tip position
                    self.lastTipFiltered = tipFiltered
```
