//
//  AchievementCelebrationView.swift
//  Wandova
//
//  Created by seren on 13.05.2026.
//

import SwiftUI

// MARK: - Confetti

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let xStart: CGFloat
    let xEnd: CGFloat
    let size: CGFloat
    let isCircle: Bool
    let delay: Double
    let duration: Double
    let startAngle: Double
    let endAngle: Double

    static func makeAll() -> [ConfettiParticle] {
        let colors: [Color] = [
            .appGold, .appVisited, .appWishlist, .appSuccess,
            Color(hex: "#60A5FA"), Color(hex: "#F472B6"),
            Color(hex: "#34D399"), Color(hex: "#FBBF24"), Color(hex: "#A78BFA")
        ]
        return (0..<60).map { _ in
            let x = CGFloat.random(in: 0.05...0.95)
            return ConfettiParticle(
                color: colors.randomElement()!,
                xStart: x,
                xEnd: x + CGFloat.random(in: -0.1...0.1),
                size: CGFloat.random(in: 7...14),
                isCircle: Bool.random(),
                delay: Double.random(in: 0...1.1),
                duration: Double.random(in: 1.8...3.2),
                startAngle: Double.random(in: 0...180),
                endAngle: Double.random(in: 360...720)
            )
        }
    }
}

private struct ConfettiView: View {
    @State private var animate = false
    @State private var particles = ConfettiParticle.makeAll()

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { p in
                Group {
                    if p.isCircle {
                        Circle()
                            .fill(p.color)
                            .frame(width: p.size, height: p.size)
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(p.color)
                            .frame(width: p.size * 0.55, height: p.size * 1.6)
                    }
                }
                .position(
                    x: geo.size.width * (animate ? p.xEnd : p.xStart),
                    y: animate ? geo.size.height + 60 : -30
                )
                .rotationEffect(.degrees(animate ? p.endAngle : p.startAngle))
                .opacity(animate ? 0 : 1)
                .animation(.easeIn(duration: p.duration).delay(p.delay), value: animate)
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

// MARK: - Celebration Overlay

struct AchievementCelebrationOverlay: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color.black
                .opacity(isVisible ? 0.52 : 0)
                .ignoresSafeArea()
                .onTapGesture { handleDismiss() }
                .animation(.easeOut(duration: 0.22), value: isVisible)

            ConfettiView()
                .ignoresSafeArea()
                .opacity(isVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.22), value: isVisible)

            // Card
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.appGold.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Circle()
                        .strokeBorder(Color.appGold.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 100, height: 100)
                    Image(systemName: achievement.icon)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(Color.appGold)
                }

                VStack(spacing: 10) {
                    Text("ACHIEVEMENT UNLOCKED")
                        .font(.custom("Inter", size: 10))
                        .fontWeight(.bold)
                        .tracking(2.5)
                        .foregroundStyle(Color.appGold)

                    Text(achievement.title)
                        .font(.custom("Fraunces-Italic-VariableFont_SOFT,WONK,opsz,wght", size: 30))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appInk)
                        .multilineTextAlignment(.center)

                    Text(achievement.description)
                        .font(.custom("Inter", size: 15))
                        .foregroundStyle(Color.appInk2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: handleDismiss) {
                    Text("Awesome!")
                        .font(.custom("Inter", size: 16))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appPaper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.appInk)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(32)
            .background(Color.appPaper)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.22), radius: 32, x: 0, y: 10)
            .padding(.horizontal, 28)
            .scaleEffect(isVisible ? 1 : 0.82)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.42, dampingFraction: 0.72), value: isVisible)
        }
        .onAppear { isVisible = true }
    }

    private func handleDismiss() {
        isVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}
