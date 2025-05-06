import Foundation
import CryptoKit

/// A service for handling network security including certificate pinning
class NetworkSecurityService {
    
    /// Local cache of trusted certificates
    private var trustedCertificates: [String: [Data]] = [:]
    
    /// Configure the shared URLSession with security features
    func configureURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        
        // Add additional headers for security
        var headers = configuration.httpAdditionalHeaders ?? [:]
        headers["X-Secure-Request"] = "true"
        configuration.httpAdditionalHeaders = headers
        
        // Set longer timeouts for API requests
        configuration.timeoutIntervalForRequest = 60.0
        configuration.timeoutIntervalForResource = 300.0
        
        // Create a session delegate that implements certificate pinning
        let delegate = CertificatePinningDelegate(trustedCertificates: trustedCertificates)
        
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    
    /// Load trusted certificates for certificate pinning
    func loadTrustedCertificates() {
        // For OpenAI
        trustedCertificates["api.openai.com"] = loadCertificatesFromBundle(withNames: ["openai-com"])
        
        // For OpenRouter
        trustedCertificates["openrouter.ai"] = loadCertificatesFromBundle(withNames: ["openrouter-ai"])
        
        // Note: In actual implementation, these would be bundled certificate files
    }
    
    /// Helper function to load certificate data from the app bundle
    private func loadCertificatesFromBundle(withNames names: [String]) -> [Data] {
        var certificatesData: [Data] = []
        
        // In a real implementation, this would load actual certificate files
        // For this prototype, we're just simulating the process
        
        // Example of what actual implementation would do:
        // for name in names {
        //     if let certificatePath = Bundle.main.path(forResource: name, ofType: "der"),
        //        let certificateData = try? Data(contentsOf: URL(fileURLWithPath: certificatePath)) {
        //         certificatesData.append(certificateData)
        //     }
        // }
        
        return certificatesData
    }
    
    /// Secure connection helper that implements certificate pinning
    class CertificatePinningDelegate: NSObject, URLSessionDelegate {
        private let trustedCertificates: [String: [Data]]
        
        init(trustedCertificates: [String: [Data]]) {
            self.trustedCertificates = trustedCertificates
            super.init()
        }
        
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, 
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            
            // Only handle server trust challenges
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let serverTrust = challenge.protectionSpace.serverTrust,
                  let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
                // Default handling for non-server trust challenges
                completionHandler(.performDefaultHandling, nil)
                return
            }
            
            // Get the host
            let host = challenge.protectionSpace.host
            
            // Check if we have trusted certificates for this host
            if let trustedCertificatesForHost = trustedCertificates[host], !trustedCertificatesForHost.isEmpty {
                // Get the server certificate data
                let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data
                
                // Check if the server certificate matches any of our trusted certificates
                let isTrusted = trustedCertificatesForHost.contains(serverCertificateData)
                
                if isTrusted {
                    // Certificate matches, trust this server
                    let credential = URLCredential(trust: serverTrust)
                    completionHandler(.useCredential, credential)
                } else {
                    // Certificate doesn't match, reject
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            } else {
                // No pinned certificates for this host, perform default validation
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
    
    /// Create an HTTP client with enhanced security for API requests
    func createSecureHTTPClient() -> URLSession {
        loadTrustedCertificates()
        return configureURLSession()
    }
    
    /// Validate a server certificate against trusted certificates
    func validateServerCertificate(for host: String, certificate: Data) -> Bool {
        guard let trustedCertificatesForHost = trustedCertificates[host] else {
            return false
        }
        
        return trustedCertificatesForHost.contains(certificate)
    }
}