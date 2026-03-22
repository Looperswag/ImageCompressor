import SwiftUI

struct CompressionSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let format: ExportFormat

    @State private var sliderValue: Double = 75

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("质量")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(format.supportsQuality ? "\(value)%" : "无损")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }

            if format.supportsQuality {
                Slider(value: $sliderValue, in: Double(range.lowerBound)...Double(range.upperBound)) {
                    Text("质量")
                } minimumValueLabel: {
                    Text("1%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .onChange(of: sliderValue) { _, newValue in
                    value = Int(newValue)
                }
                .onAppear {
                    sliderValue = Double(value)
                }
                .accessibilityLabel("质量设置")
                .accessibilityValue("\(value) 百分比")
            } else {
                Text("PNG 使用无损压缩")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("PNG 格式使用无损压缩，质量设置不适用")
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CompressionSlider(value: .constant(75), range: 1...100, format: .jpeg)
        CompressionSlider(value: .constant(100), range: 1...100, format: .png)
    }
    .padding()
    .frame(width: 300)
}
