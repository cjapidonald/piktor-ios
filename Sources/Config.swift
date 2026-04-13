import Foundation

enum AppConfig {
    static let supabaseURL = URL(string: "https://xrsmyzgdoqpqaimrtnrv.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhyc215emdkb3FwcWFpbXJ0bnJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwODU4NDAsImV4cCI6MjA5MTY2MTg0MH0.MVJZM-XZ8hEE4WIBd_PrEXN863_RBS9ZWQi0z9dEk-8"

    static let bundleId = "com.piktorstudio.app"
    static let defaultCanvasSize = 32
    static let maxCanvasSize = 128
    static let drawingsBucket = "drawings"
}
