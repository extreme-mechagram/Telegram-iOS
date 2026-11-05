import Foundation
import UIKit
import Display
import TelegramCore

func mechagramProfileColor(_ hex: String) -> UIColor? {
    guard let text = MechagramVisualProfile.normalizedColor(hex), let value = UInt32(text, radix: 16) else { return nil }
    return UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
}

func mechagramNicknameFont(_ style: MechagramVisualProfile, size: CGFloat) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: .medium)
    guard style.enabled else { return base }
    switch style.nicknameFont {
    case "rounded":
        return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
    case "serif": return UIFont(name: "Georgia-Bold", size: size) ?? base
    case "monospace": return UIFont.monospacedSystemFont(ofSize: size, weight: .medium)
    default: return base
    }
}

final class MechagramProfileBackdropView: UIView {
    private let picture = UIImageView()
    private let shade = CAGradientLayer()
    private var imagePath = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.picture.contentMode = .scaleAspectFill
        self.addSubview(self.picture)
        self.layer.addSublayer(self.shade)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(style: MechagramVisualProfile) {
        self.isHidden = !style.enabled || (style.backgroundImage.isEmpty && style.profileColor.isEmpty)
        if self.imagePath != style.backgroundImage {
            self.imagePath = style.backgroundImage
            self.picture.image = self.imagePath.isEmpty ? nil : UIImage(contentsOfFile: self.imagePath)
        }
        let color = mechagramProfileColor(style.profileColor) ?? UIColor.black
        self.backgroundColor = color
        self.shade.colors = [color.withAlphaComponent(0.2).cgColor, UIColor.black.withAlphaComponent(0.65).cgColor]
        self.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.picture.frame = self.bounds
        self.shade.frame = self.bounds
    }
}

final class MechagramAvatarFrameView: UIView {
    private let outline = CAShapeLayer()
    private let beads = CAShapeLayer()
    private let charm = UILabel()
    private let sparkles = (0..<6).map { _ in UILabel() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = false
        self.layer.addSublayer(self.outline)
        self.layer.addSublayer(self.beads)
        self.outline.fillColor = UIColor.clear.cgColor
        self.addSubview(self.charm)
        for label in self.sparkles { self.addSubview(label) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(style: MechagramVisualProfile) {
        self.isHidden = !style.enabled || style.framePreset == "none"
        guard !self.isHidden, self.bounds.width > 0 else {
            for label in self.sparkles { label.layer.removeAnimation(forKey: "mechagram.sparkle") }
            return
        }
        let color = mechagramProfileColor(style.frameColor) ?? UIColor.systemRed
        let rect = self.bounds.insetBy(dx: 3, dy: 3)
        let path: UIBezierPath
        switch style.frameShape {
        case "square": path = UIBezierPath(roundedRect: rect, cornerRadius: 3)
        case "rounded": path = UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.24)
        case "hex":
            path = UIBezierPath()
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3 - .pi / 2
                let point = CGPoint(x: rect.midX + cos(angle) * rect.width / 2, y: rect.midY + sin(angle) * rect.height / 2)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.close()
        default: path = UIBezierPath(ovalIn: rect)
        }
        self.outline.path = path.cgPath
        self.outline.strokeColor = color.cgColor
        self.outline.lineWidth = min(12, max(1, CGFloat(style.frameWidth)))
        self.outline.shadowColor = color.cgColor
        self.outline.shadowRadius = 5
        self.outline.shadowOpacity = 0.7
        self.outline.shadowOffset = .zero
        self.beads.path = path.cgPath
        self.beads.fillColor = UIColor.clear.cgColor
        self.beads.strokeColor = UIColor.white.cgColor
        self.beads.lineWidth = 6
        self.beads.lineDashPattern = [0, 12]
        self.beads.lineCap = .round
        self.beads.isHidden = style.framePreset != "beads"
        self.charm.text = style.decoration.isEmpty ? "💎" : style.decoration
        self.charm.font = UIFont.systemFont(ofSize: min(44, max(22, self.bounds.width * 0.22)))
        self.charm.textAlignment = .center
        self.charm.frame = CGRect(x: self.bounds.width - 35, y: self.bounds.height - 40, width: 55, height: 55)
        self.charm.isHidden = style.framePreset != "gem"
        for (index, label) in self.sparkles.enumerated() {
            label.isHidden = style.framePreset != "sparks"
            label.text = style.decoration.isEmpty ? "✨" : style.decoration
            label.font = UIFont.systemFont(ofSize: 20)
            let angle = CGFloat(index) * .pi / 3
            label.frame = CGRect(x: rect.midX + cos(angle) * (rect.width / 2 + 5) - 14, y: rect.midY + sin(angle) * (rect.height / 2 + 5) - 14, width: 28, height: 28)
            if !label.isHidden && !UIAccessibility.isReduceMotionEnabled && label.layer.animation(forKey: "mechagram.sparkle") == nil {
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.fromValue = 0.25
                animation.toValue = 1
                animation.duration = 0.9 + Double(index) * 0.13
                animation.autoreverses = true
                animation.repeatCount = .infinity
                label.layer.add(animation, forKey: "mechagram.sparkle")
            } else if label.isHidden || UIAccessibility.isReduceMotionEnabled { label.layer.removeAnimation(forKey: "mechagram.sparkle") }
        }
    }
}
