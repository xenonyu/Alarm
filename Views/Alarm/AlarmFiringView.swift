import SwiftUI

/// Full-screen alarm view shown when an alarm fires.
/// Displayed over the entire UI; user must Stop or Snooze to dismiss.
struct AlarmFiringView: View {

    @Environment(AlarmAudioService.self) private var audio
    @Environment(AppSettings.self) private var settings

    @State private var pulse = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Alarm icon with pulse animation
                Image(systemName: "alarm.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .scaleEffect(pulse ? 1.12 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                        value: pulse
                    )
                    .padding(.bottom, 32)

                // Time
                Text(audio.firingTime, style: .time)
                    .font(.system(size: 80, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                // Title
                if !audio.firingTitle.isEmpty {
                    Text(audio.firingTitle)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 8)
                }

                Spacer()
                Spacer()

                // Snooze button
                Button {
                    audio.snooze(minutes: settings.snoozeMinutes)
                } label: {
                    Label("Snooze \(settings.snoozeMinutes) min",
                          systemImage: "moon.zzz.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.white.opacity(0.9))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

                // Stop button
                Button {
                    audio.stop()
                } label: {
                    Text("Stop")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .onAppear { pulse = true }
        .statusBarHidden(true)
    }
}
