package main

import (
	"bytes"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"io/ioutil"
	"math/big"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	// System message types
	MSG_SYSTEM_TERMINATE      = 0xFFFFFFFF
	MSG_SYSTEM_NEW_COORDINATOR = 0xFFFFFFFE

	// Application message types
	GEMINI_REQUEST  = 1
	GEMINI_RESPONSE = 101

	// Bookmark message types
	BOOKMARK_ADD    = 201
	BOOKMARK_REMOVE = 202
	BOOKMARK_LIST   = 203
	BOOKMARK_RESPONSE = 301

	// Input message types
	INPUT_REQUEST      = 401  // Backend requests input from frontend
	INPUT_RESPONSE     = 402  // Frontend responds with input data
	INPUT_CANCEL       = 403  // Frontend cancels input request

	// Certificate message types
	CERTIFICATE_LIST       = 601
	CERTIFICATE_ADD        = 602
	CERTIFICATE_REMOVE     = 603
	CERTIFICATE_GENERATE   = 604
	CERTIFICATE_RESPONSE   = 605
	CERTIFICATE_SELECT     = 606  // Backend requests certificate selection
	CERTIFICATE_SELECT_RESPONSE = 607  // Frontend responds with selected certificate
	CERTIFICATE_LIST_ASSOCIATIONS = 608  // Request list of certificate associations
	CERTIFICATE_DISASSOCIATE = 609  // Remove domain-certificate association
	CERTIFICATE_EXPIRED    = 610  // Certificate has expired
	CERTIFICATE_BYPASS     = 611  // User chose to bypass certificate validation

	// Settings message types
	SETTINGS_GET           = 701  // Frontend requests current settings
	SETTINGS_SAVE          = 702  // Frontend sends updated settings
	SETTINGS_RESPONSE      = 703  // Backend sends current settings

	// Inline image message types
	INLINE_IMAGE_REQUEST   = 150  // Frontend requests inline image fetch
	INLINE_IMAGE_RESPONSE  = 151  // Backend sends inline image data

	// Refresh mode message types
	REFRESH_MODE_SWITCH    = 501

	// Maximum package size (10MB)
	MAX_PACKAGE_SIZE = 10485760
)

// MessageHeader represents the 8-byte header for AppLoad messages
type MessageHeader struct {
	MsgType uint32 // Message type identifier
	Length  uint32 // Length of content in bytes
}

// Message represents a complete AppLoad message
type Message struct {
	MsgType uint32
	Content string
}

// Bookmark represents a saved URL with metadata
type Bookmark struct {
	Title     string `json:"title"`
	URL       string `json:"url"`
	DateAdded string `json:"dateAdded"` // ISO 8601 format
}

// BookmarkResponse represents the response structure for bookmark operations
type BookmarkResponse struct {
	Success  bool      `json:"success"`
	Bookmarks []Bookmark `json:"bookmarks"`
	Error    string    `json:"error,omitempty"`
}

// Certificate represents a client certificate for Gemini authentication
type Certificate struct {
	Subject     string `json:"subject"`
	Issuer      string `json:"issuer"`
	NotBefore   string `json:"notBefore"`   // ISO 8601 format
	NotAfter    string `json:"notAfter"`    // ISO 8601 format
	Fingerprint string `json:"fingerprint"` // SHA-256 fingerprint (used as unique identifier)
	CertPEM     string `json:"certPEM,omitempty"` // PEM encoded certificate
	KeyPEM      string `json:"keyPEM,omitempty"`  // PEM encoded private key
}

// CertificateResponse represents the response structure for certificate operations
type CertificateResponse struct {
	Success      bool            `json:"success"`
	Certificates []Certificate   `json:"certificates"`
	Associations map[string]string `json:"associations"`  // Removed omitempty to ensure empty maps are sent
	Error        string          `json:"error,omitempty"`
}

// InputRequest represents a request for user input from the frontend
type InputRequest struct {
	Prompt   string `json:"prompt"`
	Sensitive bool  `json:"sensitive"`
	URL      string `json:"url"`
}

// CertificateSelectRequest represents a request for certificate selection from the frontend
type CertificateSelectRequest struct {
	Prompt   string        `json:"prompt"`
	Meta     string        `json:"meta"`
	URL      string        `json:"url"`
	Certificates []Certificate `json:"certificates,omitempty"`
}

// Settings represents the application settings
type Settings struct {
	Padding     int       `json:"padding"`
	TextSize    int       `json:"textSize"`
	Homepage    string    `json:"homepage,omitempty"`
	Bookmarks   []Bookmark `json:"bookmarks"`
	BypassedURLs []string  `json:"bypassedUrls,omitempty"`
	ProxyURL    string    `json:"proxyUrl"`
	ProxyPort   int       `json:"proxyPort"`
	RefreshMode string    `json:"refreshMode,omitempty"`  // Refresh mode setting: "auto", "quality", "fast", "ufast", "animate", or "ui"
}

// SettingsResponse represents the response structure for settings operations
type SettingsResponse struct {
	Success  bool     `json:"success"`
	Settings Settings `json:"settings,omitempty"`
	Error    string   `json:"error,omitempty"`
}

// CertificateSelectResponse represents the response with selected certificate fingerprint from frontend
type CertificateSelectResponse struct {
	URL          string `json:"url"`
	CertificateId string `json:"certificateId"` // This now contains the certificate fingerprint
}

// GenerateCertificateRequest represents the request structure for generating a certificate
type GenerateCertificateRequest struct {
	CommonName string `json:"commonName"`
}

// AppLoadBackend interface for handling messages
type AppLoadBackend interface {
	HandleMessage(replier *BackendReplier, message Message)
}

// BackendReplier handles sending messages back to the frontend
type BackendReplier struct {
	fd     int
	locked bool
}


// CertificateManager handles certificate operations
type CertificateManager struct {
	certDir       string
	assocFilePath string
	mutex         sync.RWMutex
}

// AppLoad manages the connection and communication with AppLoad
type AppLoad struct {
	fd      int
	backend AppLoadBackend
}

// NewAppLoad creates a new AppLoad connection
func NewAppLoad(socketPath string, backend AppLoadBackend) (*AppLoad, error) {
	// Create Unix socket with SOCK_SEQPACKET
	fd, err := syscall.Socket(syscall.AF_UNIX, syscall.SOCK_SEQPACKET, 0)
	if err != nil {
		return nil, fmt.Errorf("failed to create socket: %v", err)
	}

	// Connect to the socket
	addr := &syscall.SockaddrUnix{Name: socketPath}
	err = syscall.Connect(fd, addr)
	if err != nil {
		syscall.Close(fd)
		return nil, fmt.Errorf("failed to connect to socket: %v", err)
	}

	return &AppLoad{
		fd:      fd,
		backend: backend,
	}, nil
}

// Close closes the AppLoad connection
func (app *AppLoad) Close() error {
	return syscall.Close(app.fd)
}

// CreateReplier creates a new BackendReplier for sending messages
func (app *AppLoad) CreateReplier() *BackendReplier {
	return &BackendReplier{
		fd:     app.fd,
		locked: false,
	}
}

// Run starts the message processing loop
func (app *AppLoad) Run() error {
	replier := app.CreateReplier()

	for {
		// Read message header (8 bytes)
		headerBytes := make([]byte, 8)
		n, err := syscall.Read(app.fd, headerBytes)
		if err != nil {
			break
		}

		if n == 0 {
			break
		}

		if n < 8 {
			continue
		}

		// Parse header (little-endian)
		msgType := binary.LittleEndian.Uint32(headerBytes[0:4])
		length := binary.LittleEndian.Uint32(headerBytes[4:8])

		// Check if message size is within limits
		if length > MAX_PACKAGE_SIZE {
			return fmt.Errorf("message exceeds protocol spec")
		}

		// Read message content
		var content string
		if length > 0 {
			buffer := make([]byte, length)
			n, err := syscall.Read(app.fd, buffer)
			if err != nil {
				return fmt.Errorf("failed to read message content: %v", err)
			}

			if uint32(n) < length {
				continue
			}

			content = string(buffer)
		}

		// Handle the message
		message := Message{
			MsgType: msgType,
			Content: content,
		}

		app.backend.HandleMessage(replier, message)
	}

	// Send terminate message when connection closes
	terminateMsg := Message{
		MsgType: MSG_SYSTEM_TERMINATE,
		Content: "",
	}
	app.backend.HandleMessage(replier, terminateMsg)

	return nil
}

// SendMessage sends a message to the frontend
func (replier *BackendReplier) SendMessage(msgType uint32, content string) error {
	if replier.locked {
		return fmt.Errorf("cannot send message to terminating frontend")
	}

	// Create header (little-endian)
	headerBytes := make([]byte, 8)
	binary.LittleEndian.PutUint32(headerBytes[0:4], msgType)
	binary.LittleEndian.PutUint32(headerBytes[4:8], uint32(len(content)))

	// Send header
	_, err := syscall.Write(replier.fd, headerBytes)
	if err != nil {
		return fmt.Errorf("failed to send header: %v", err)
	}

	// Send content if any
	if len(content) > 0 {
		_, err = syscall.Write(replier.fd, []byte(content))
		if err != nil {
			return fmt.Errorf("failed to send content: %v", err)
		}
	}

	return nil
}


// NewCertificateManager creates a new certificate manager
func NewCertificateManager() (*CertificateManager, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get user home directory: %v", err)
	}

	// Path for certificates file
	certFilePath := filepath.Join(homeDir, ".gemini-certificates.json")

	// Create certificates file if it doesn't exist
	if _, err := os.Stat(certFilePath); os.IsNotExist(err) {
		// Create empty certificates file
		certificates := struct {
			Certificates []Certificate     `json:"certificates"`
			Associations map[string]string `json:"associations"` // domain -> cert fingerprint
		}{
			Certificates: []Certificate{},
			Associations: make(map[string]string),
		}

		data, err := json.MarshalIndent(certificates, "", "  ")
		if err != nil {
			return nil, fmt.Errorf("failed to create initial certificates file: %v", err)
		}

		if err := os.WriteFile(certFilePath, data, 0600); err != nil {
			return nil, fmt.Errorf("failed to write initial certificates file: %v", err)
		}
	}

	return &CertificateManager{
		certDir:       filepath.Dir(certFilePath),
		assocFilePath: certFilePath, // Use the same file for both certificates and associations
	}, nil
}

// ListCertificates returns all certificates
func (cm *CertificateManager) ListCertificates() ([]Certificate, error) {
	cm.mutex.RLock()
	defer cm.mutex.RUnlock()

	// Read certificates from JSON file
	data, err := os.ReadFile(cm.assocFilePath) // This file now contains both certificates and associations
	if err != nil {
		return nil, fmt.Errorf("failed to read certificates file: %v", err)
	}

	var certData struct {
		Certificates []Certificate     `json:"certificates"`
		Associations map[string]string `json:"associations"` // domain -> cert fingerprint
	}

	if err := json.Unmarshal(data, &certData); err != nil {
		return nil, fmt.Errorf("failed to parse certificates file: %v", err)
	}

	return certData.Certificates, nil
}

// GetCertificateForDomain returns the certificate fingerprint associated with a domain
func (cm *CertificateManager) GetCertificateForDomain(domain string) (string, error) {
	cm.mutex.RLock()
	defer cm.mutex.RUnlock()

	// Read associations file
	data, err := os.ReadFile(cm.assocFilePath)
	if err != nil {
		return "", fmt.Errorf("failed to read associations file: %v", err)
	}

	var associations struct {
		Associations map[string]string `json:"associations"` // domain -> cert fingerprint
	}

	if err := json.Unmarshal(data, &associations); err != nil {
		return "", fmt.Errorf("failed to parse associations file: %v", err)
	}

	certId, exists := associations.Associations[domain]
	if !exists {
		return "", fmt.Errorf("no certificate associated with domain: %s", domain)
	}

	return certId, nil
}

// SetCertificateForDomain associates a certificate fingerprint with a domain
func (cm *CertificateManager) SetCertificateForDomain(domain, certId string) error {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	// Read existing certificates and associations
	data, err := os.ReadFile(cm.assocFilePath)
	if err != nil {
		return fmt.Errorf("failed to read certificates file: %v", err)
	}

	var certData struct {
		Certificates []Certificate     `json:"certificates"`
		Associations map[string]string `json:"associations"` // domain -> cert fingerprint
	}

	if err := json.Unmarshal(data, &certData); err != nil {
		return fmt.Errorf("failed to parse certificates file: %v", err)
	}

	// Initialize associations map if nil
	if certData.Associations == nil {
		certData.Associations = make(map[string]string)
	}

	// Set the association
	certData.Associations[domain] = certId

	// Save updated certificates and associations
	newData, err := json.MarshalIndent(certData, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal certificates data: %v", err)
	}

	if err := os.WriteFile(cm.assocFilePath, newData, 0600); err != nil {
		return fmt.Errorf("failed to write certificates file: %v", err)
	}

	return nil
}

// loadCertificateByFingerprint loads a certificate by its fingerprint from the JSON file
func (b *GeminiBackend) loadCertificateByFingerprint(fingerprint string) (tls.Certificate, error) {
	certificates, err := b.certificateManager.ListCertificates()
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("failed to list certificates: %v", err)
	}

	// Find the certificate with the matching fingerprint
	var certData *Certificate
	for _, cert := range certificates {
		if cert.Fingerprint == fingerprint {
			certData = &cert
			break
		}
	}

	if certData == nil {
		return tls.Certificate{}, fmt.Errorf("certificate not found: %s", fingerprint)
	}

	// Parse the PEM data
	certBlock, _ := pem.Decode([]byte(certData.CertPEM))
	if certBlock == nil {
		return tls.Certificate{}, fmt.Errorf("failed to decode certificate PEM")
	}

	keyBlock, _ := pem.Decode([]byte(certData.KeyPEM))
	if keyBlock == nil {
		return tls.Certificate{}, fmt.Errorf("failed to decode key PEM")
	}

	// Parse the certificate and key
	cert, err := x509.ParseCertificate(certBlock.Bytes)
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("failed to parse certificate: %v", err)
	}

	key, err := x509.ParsePKCS8PrivateKey(keyBlock.Bytes)
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("failed to parse key: %v", err)
	}

	// Create TLS certificate
	tlsCert := tls.Certificate{
		Certificate: [][]byte{cert.Raw},
		PrivateKey:  key,
		Leaf:        cert,
	}

	return tlsCert, nil
}

// ListAssociations returns all domain-to-certificate associations
func (cm *CertificateManager) ListAssociations() (map[string]string, error) {
	cm.mutex.RLock()
	defer cm.mutex.RUnlock()

	// Read associations file
	data, err := os.ReadFile(cm.assocFilePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read associations file: %v", err)
	}

	var associations struct {
		Associations map[string]string `json:"associations"` // domain -> cert fingerprint
	}

	if err := json.Unmarshal(data, &associations); err != nil {
		return nil, fmt.Errorf("failed to parse associations file: %v", err)
	}

	// Return a copy of the associations map
	result := make(map[string]string)
	for domain, certId := range associations.Associations {
		result[domain] = certId
	}

	return result, nil
}

// GenerateCertificate creates a new self-signed certificate
func (cm *CertificateManager) GenerateCertificate(commonName string) (Certificate, error) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	// Generate private key
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return Certificate{}, fmt.Errorf("failed to generate private key: %v", err)
	}

	// Create certificate template
	notBefore := time.Now()
	notAfter := notBefore.Add(365 * 24 * time.Hour) // 1 year validity

	serialNumber, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128))
	if err != nil {
		return Certificate{}, fmt.Errorf("failed to generate serial number: %v", err)
	}

	template := x509.Certificate{
		SerialNumber: serialNumber,
		Subject: pkix.Name{
			CommonName:   commonName,
			Organization: []string{"Irilon Browser"},
		},
		NotBefore:             notBefore,
		NotAfter:              notAfter,
		KeyUsage:              x509.KeyUsageKeyEncipherment | x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth},
		BasicConstraintsValid: true,
	}

	// Create certificate
	certBytes, err := x509.CreateCertificate(rand.Reader, &template, &template, &privateKey.PublicKey, privateKey)
	if err != nil {
		return Certificate{}, fmt.Errorf("failed to create certificate: %v", err)
	}

	// Parse certificate for information
	cert, err := x509.ParseCertificate(certBytes)
	if err != nil {
		return Certificate{}, fmt.Errorf("failed to parse certificate: %v", err)
	}

	// Encode certificate and key as PEM strings for storage in JSON
	certPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: certBytes})
	privBytes, err := x509.MarshalPKCS8PrivateKey(privateKey)
	if err != nil {
		return Certificate{}, fmt.Errorf("failed to marshal private key: %v", err)
	}
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: privBytes})

	// Calculate fingerprint (used as unique identifier)
	fingerprint := sha256.Sum256(cert.Raw)
	fingerprintStr := fmt.Sprintf("%x", fingerprint)

	// Create certificate object with PEM data
	certificate := Certificate{
		Subject:     cert.Subject.String(),
		Issuer:      cert.Issuer.String(),
		NotBefore:   cert.NotBefore.Format(time.RFC3339),
		NotAfter:    cert.NotAfter.Format(time.RFC3339),
		Fingerprint: fingerprintStr,
		CertPEM:     string(certPEM),
		KeyPEM:      string(keyPEM),
	}

	// Load existing certificates and associations
	data, err := os.ReadFile(cm.assocFilePath)
	if err != nil {
		return Certificate{}, fmt.Errorf("failed to read certificates file: %v", err)
	}

	var certData struct {
		Certificates []Certificate     `json:"certificates"`
		Associations map[string]string `json:"associations"` // domain -> cert fingerprint
	}

	if err := json.Unmarshal(data, &certData); err != nil {
		return Certificate{}, fmt.Errorf("failed to parse certificates file: %v", err)
	}

	// Add new certificate to the list
	certData.Certificates = append(certData.Certificates, certificate)

	// Save updated data
	newData, err := json.MarshalIndent(certData, "", "  ")
	if err != nil {
		return Certificate{}, fmt.Errorf("failed to marshal certificates data: %v", err)
	}

	if err := os.WriteFile(cm.assocFilePath, newData, 0600); err != nil {
		return Certificate{}, fmt.Errorf("failed to write certificates file: %v", err)
	}

	return certificate, nil
}

// RemoveCertificate removes a certificate by its fingerprint
func (cm *CertificateManager) RemoveCertificate(fingerprint string) error {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	// Read existing certificates and associations
	data, err := os.ReadFile(cm.assocFilePath)
	if err != nil {
		return fmt.Errorf("failed to read certificates file: %v", err)
	}

	var certData struct {
		Certificates []Certificate     `json:"certificates"`
		Associations map[string]string `json:"associations"` // domain -> cert fingerprint
	}

	if err := json.Unmarshal(data, &certData); err != nil {
		return fmt.Errorf("failed to parse certificates file: %v", err)
	}

	// Remove the certificate with the matching fingerprint
	found := false
	newCertificates := make([]Certificate, 0, len(certData.Certificates))
	for _, cert := range certData.Certificates {
		if cert.Fingerprint == fingerprint {
			found = true
			// Don't add this certificate to the new list
		} else {
			newCertificates = append(newCertificates, cert)
		}
	}

	if !found {
		return fmt.Errorf("certificate not found: %s", fingerprint)
	}

	certData.Certificates = newCertificates

	// Also remove any associations that reference this certificate
	removedAssociations := 0
	for domain, certFingerprint := range certData.Associations {
		if certFingerprint == fingerprint {
			delete(certData.Associations, domain)
			removedAssociations++
		}
	}

	// Save updated certificates and associations
	newData, err := json.MarshalIndent(certData, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal certificates data: %v", err)
	}

	if err := os.WriteFile(cm.assocFilePath, newData, 0600); err != nil {
		return fmt.Errorf("failed to write certificates file: %v", err)
	}

	return nil
}






// GeminiResponse represents the response structure sent to the frontend
type GeminiResponse struct {
	Success bool   `json:"success"`
	URL     string `json:"url"`
	Content string `json:"content,omitempty"`
	Error   string `json:"error,omitempty"`
}

// SettingsManager handles application settings
type SettingsManager struct {
	settingsFile string
	mutex        sync.RWMutex
}


// getDefaultBookmarks returns the default bookmarks embedded in the application
func getDefaultBookmarks() []Bookmark {
	return []Bookmark{
		{
			Title:     "🌒 BBS",
			URL:       "gemini://bbs.geminispace.org",
			DateAdded: "2026-02-01T23:25:31Z",
		},
		{
			Title:     "Cosmos",
			URL:       "gemini://skyjake.fi/~Cosmos/",
			DateAdded: "2026-02-07T19:25:48Z",
		},
		{
			Title:     "Antenna",
			URL:       "gemini://warmedal.se/~antenna/",
			DateAdded: "2026-02-07T19:25:48Z",
		},
		{
			Title:     "Station",
			URL:       "gemini://station.martinrue.com",
			DateAdded: "2026-02-07T19:25:48Z",
		},
		{
			Title: "Newswaffle",
			URL: "gemini://gemi.dev/cgi-bin/waffle.cgi",
			DateAdded: "2026-02-07T19:25:48Z",	
		},
		{
			Title: "CAPCOM",
			URL: "gemini://gemini.circumlunar.space/capcom/",
			DateAdded: "2026-02-07T19:25:48Z",	
		},
		{
			Title: "Kennedy Search Engine",
			URL: "gemini://kennedy.gemi.dev",
			DateAdded: "2026-02-07T19:25:48Z",	
		},
	}
}

// NewSettingsManager creates a new settings manager
func NewSettingsManager() (*SettingsManager, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get user home directory: %v", err)
	}

	settingsFile := filepath.Join(homeDir, ".irilon-settings.json")

	// Create file if it doesn't exist
	if _, err := os.Stat(settingsFile); os.IsNotExist(err) {
		// Load default bookmarks
		defaultBookmarks := getDefaultBookmarks()

		// Create default settings with default bookmarks
		settings := Settings{
			Padding:      50,
			TextSize:     18,
			Homepage:     "gemini://geminiprotocol.net/",
			Bookmarks:    defaultBookmarks,
			BypassedURLs: []string{},
			ProxyURL:     "",
			ProxyPort:    0,
		}

		data, err := json.MarshalIndent(settings, "", "  ")
		if err != nil {
			return nil, fmt.Errorf("failed to create initial settings file: %v", err)
		}

		if err := os.WriteFile(settingsFile, data, 0644); err != nil {
			return nil, fmt.Errorf("failed to write initial settings file: %v", err)
		}
	}

	return &SettingsManager{
		settingsFile: settingsFile,
	}, nil
}

// LoadSettings loads settings from the JSON file
func (sm *SettingsManager) LoadSettings() (Settings, error) {
	sm.mutex.RLock()
	defer sm.mutex.RUnlock()

	data, err := os.ReadFile(sm.settingsFile)
	if err != nil {
		return Settings{}, fmt.Errorf("failed to read settings file: %v", err)
	}

	var settings Settings
	if err := json.Unmarshal(data, &settings); err != nil {
		return Settings{}, fmt.Errorf("failed to parse settings file: %v", err)
	}

	return settings, nil
}

// SaveSettings saves settings to the JSON file
func (sm *SettingsManager) SaveSettings(settings Settings) error {
	sm.mutex.Lock()
	defer sm.mutex.Unlock()

	data, err := json.MarshalIndent(settings, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal settings: %v", err)
	}

	if err := os.WriteFile(sm.settingsFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write settings file: %v", err)
	}

	return nil
}

// GeminiBackend handles Gemini protocol requests
type GeminiBackend struct{
	certificateManager *CertificateManager
	settingsManager    *SettingsManager
	bypassedURLs       map[string]bool  // URLs that have been bypassed for certificate validation
	bypassedURLsMutex  sync.RWMutex     // Mutex to protect bypassedURLs map
}

// HandleMessage processes messages from the QML frontend
func (b *GeminiBackend) HandleMessage(replier *BackendReplier, message Message) {
	switch message.MsgType {
	case MSG_SYSTEM_NEW_COORDINATOR:
		// Frontend connected - no logging needed
	case MSG_SYSTEM_TERMINATE:
		// Frontend terminating - no logging needed
	case GEMINI_REQUEST:
		b.fetchGeminiPageWithRedirectCount(replier, message.Content, 0)
	case INLINE_IMAGE_REQUEST:
		b.fetchGeminiPageWithRedirectCount(replier, message.Content, 0)
	case BOOKMARK_ADD:
		b.handleAddBookmark(replier, message.Content)
	case BOOKMARK_REMOVE:
		b.handleRemoveBookmark(replier, message.Content)
	case BOOKMARK_LIST:
		b.handleListBookmarks(replier)
	case CERTIFICATE_LIST:
		b.handleListCertificates(replier)
	case CERTIFICATE_GENERATE:
		b.handleGenerateCertificate(replier, message.Content)
	case CERTIFICATE_LIST_ASSOCIATIONS:
		b.handleListCertificateAssociations(replier)
	case CERTIFICATE_REMOVE:
		b.handleRemoveCertificate(replier, message.Content)
	case CERTIFICATE_DISASSOCIATE:
		b.handleDisassociateDomain(replier, message.Content)
	case CERTIFICATE_SELECT_RESPONSE:
		b.handleCertificateSelectResponse(replier, message.Content)
	case CERTIFICATE_BYPASS:
		b.addBypassedURL(message.Content)
	case REFRESH_MODE_SWITCH:
		refreshMode := b.mapRefreshMode(message.Content)
		refreshModeBytes := make([]byte, 4)
		binary.LittleEndian.PutUint32(refreshModeBytes, uint32(refreshMode))
		replier.SendMessage(5, string(refreshModeBytes))
	case SETTINGS_GET:
		b.handleGetSettings(replier)
	case SETTINGS_SAVE:
		b.handleSaveSettings(replier, message.Content)
	}
}

// handleAddBookmark handles adding a new bookmark
func (b *GeminiBackend) handleAddBookmark(replier *BackendReplier, content string) {
	// Parse content as JSON: {"title": "Page Title", "url": "gemini://..."}
	var bookmarkData struct {
		Title string `json:"title"`
		URL   string `json:"url"`
	}

	if err := json.Unmarshal([]byte(content), &bookmarkData); err != nil {
		response := BookmarkResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to parse bookmark data: %v", err),
		}
		b.sendBookmarkResponse(replier, response)
		return
	}

	// Load current settings
	settings, err := b.settingsManager.LoadSettings()
	if err != nil {
		response := BookmarkResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to load settings: %v", err),
		}
		b.sendBookmarkResponse(replier, response)
		return
	}

	// Check if bookmark already exists
	for _, bookmark := range settings.Bookmarks {
		if bookmark.URL == bookmarkData.URL {
			response := BookmarkResponse{
				Success: false,
				Error:   fmt.Sprintf("Bookmark already exists for URL: %s", bookmarkData.URL),
			}
			b.sendBookmarkResponse(replier, response)
			return
		}
	}

	// Add new bookmark
	newBookmark := Bookmark{
		Title:     bookmarkData.Title,
		URL:       bookmarkData.URL,
		DateAdded: time.Now().UTC().Format(time.RFC3339),
	}

	settings.Bookmarks = append(settings.Bookmarks, newBookmark)

	// Save updated settings
	if err := b.settingsManager.SaveSettings(settings); err != nil {
		response := BookmarkResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to save bookmark: %v", err),
		}
		b.sendBookmarkResponse(replier, response)
		return
	}

	response := BookmarkResponse{
		Success: true,
	}
	b.sendBookmarkResponse(replier, response)
}

// handleRemoveBookmark handles removing a bookmark
func (b *GeminiBackend) handleRemoveBookmark(replier *BackendReplier, url string) {
	// Validate URL parameter
	if url == "" {
		response := BookmarkResponse{
			Success: false,
			Error:   "URL parameter is required",
		}
		b.sendBookmarkResponse(replier, response)
		return
	}

	// Load current settings
	settings, err := b.settingsManager.LoadSettings()
	if err != nil {
		response := BookmarkResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to load settings: %v", err),
		}
		b.sendBookmarkResponse(replier, response)
		return
	}

	// Find and remove bookmark
	found := false
	newBookmarks := []Bookmark{}
	for _, bookmark := range settings.Bookmarks {
		if bookmark.URL == url {
			found = true
			// Skip this bookmark (effectively removing it)
			continue
		}
		newBookmarks = append(newBookmarks, bookmark)
	}

	if !found {
		// Even if bookmark not found, send back the current list of bookmarks
		// to ensure frontend has the correct state
		response := BookmarkResponse{
			Success:   true,  // Operation completed successfully even if bookmark wasn't found
			Bookmarks: settings.Bookmarks,
			Error:     fmt.Sprintf("Bookmark not found for URL: %s", url),
		}
		b.sendBookmarkResponse(replier, response)
		return
	}

	// Update bookmarks in settings
	settings.Bookmarks = newBookmarks

	// Save updated settings
	if err := b.settingsManager.SaveSettings(settings); err != nil {
		response := BookmarkResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to save bookmarks: %v", err),
		}
		b.sendBookmarkResponse(replier, response)
		return
	}

	// Send the updated list of bookmarks
	response := BookmarkResponse{
		Success:   true,
		Bookmarks: settings.Bookmarks,
	}
	b.sendBookmarkResponse(replier, response)
}

// handleListBookmarks handles listing all bookmarks
func (b *GeminiBackend) handleListBookmarks(replier *BackendReplier) {
	// Load settings to get bookmarks
	settings, err := b.settingsManager.LoadSettings()
	if err != nil {
		response := BookmarkResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to load settings: %v", err),
		}
		b.sendBookmarkResponse(replier, response)
		return
	}

	// Use bookmarks from settings
	bookmarks := settings.Bookmarks

	response := BookmarkResponse{
		Success:   true,
		Bookmarks: bookmarks,
	}
	b.sendBookmarkResponse(replier, response)
}

// sendBookmarkResponse sends a bookmark response to the frontend
func (b *GeminiBackend) sendBookmarkResponse(replier *BackendReplier, response BookmarkResponse) {
	jsonResponse, err := json.Marshal(response)
	if err != nil {
		return
	}

	err = replier.SendMessage(BOOKMARK_RESPONSE, string(jsonResponse))
	if err != nil {
	}
}

// handleListCertificates handles listing all certificates
func (b *GeminiBackend) handleListCertificates(replier *BackendReplier) {
	certificates, err := b.certificateManager.ListCertificates()
	if err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to load certificates: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	response := CertificateResponse{
		Success:      true,
		Certificates: certificates,
	}
	b.sendCertificateResponse(replier, response)
}

// handleGenerateCertificate handles generating a new certificate
func (b *GeminiBackend) handleGenerateCertificate(replier *BackendReplier, content string) {
	var req GenerateCertificateRequest
	if err := json.Unmarshal([]byte(content), &req); err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to parse certificate request: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	if _, err := b.certificateManager.GenerateCertificate(req.CommonName); err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to generate certificate: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	// After generating a certificate, send the complete list of certificates
	certificates, err := b.certificateManager.ListCertificates()
	if err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to load certificates: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	response := CertificateResponse{
		Success:      true,
		Certificates: certificates,
	}
	b.sendCertificateResponse(replier, response)
}

// handleRemoveCertificate handles removing a certificate
func (b *GeminiBackend) handleRemoveCertificate(replier *BackendReplier, content string) {
	// Content should be the fingerprint of the certificate to remove
	fingerprint := strings.TrimSpace(content)
	if fingerprint == "" {
		response := CertificateResponse{
			Success: false,
			Error:   "Empty fingerprint provided",
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	if err := b.certificateManager.RemoveCertificate(fingerprint); err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to remove certificate: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	// After removing a certificate, send the updated list of certificates
	certificates, err := b.certificateManager.ListCertificates()
	if err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to load certificates: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	// Also get updated associations
	associations, err := b.certificateManager.ListAssociations()
	if err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to load associations: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	response := CertificateResponse{
		Success:      true,
		Certificates: certificates,
	}
	b.sendCertificateResponse(replier, response)

	// Send updated associations as well
	assocResponse := struct {
		Success      bool              `json:"success"`
		Associations map[string]string `json:"associations"`  // Removed omitempty to ensure empty maps are sent
		Error        string            `json:"error,omitempty"`
	}{
		Success:      true,
		Associations: associations,
	}

	jsonResponse, err := json.Marshal(assocResponse)
	if err != nil {
		return
	}

	err = replier.SendMessage(CERTIFICATE_SELECT_RESPONSE, string(jsonResponse))
	if err != nil {
	}
}

// handleDisassociateDomain handles removing a domain-certificate association
func (b *GeminiBackend) handleDisassociateDomain(replier *BackendReplier, content string) {
	// Content should be the domain to disassociate
	domain := strings.TrimSpace(content)
	if domain == "" {
		response := CertificateResponse{
			Success: false,
			Error:   "Empty domain provided",
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	// Read existing associations
	data, err := os.ReadFile(b.certificateManager.assocFilePath)
	if err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to read associations file: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	var certData struct {
		Certificates []Certificate     `json:"certificates"`
		Associations map[string]string `json:"associations"` // domain -> cert fingerprint
	}

	if err := json.Unmarshal(data, &certData); err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to parse associations file: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	// Remove the association
	if _, exists := certData.Associations[domain]; exists {
		delete(certData.Associations, domain)
	} else {
		// This isn't really an error, just means there was no association
	}

	// Save updated associations
	newData, err := json.MarshalIndent(certData, "", "  ")
	if err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to marshal associations data: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	if err := os.WriteFile(b.certificateManager.assocFilePath, newData, 0600); err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to write associations file: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	// Send updated associations list directly from the in-memory data
	// to avoid potential race conditions with file reading
	// Ensure we send an empty map rather than nil when there are no associations
	associationsToSend := certData.Associations
	if associationsToSend == nil {
		associationsToSend = make(map[string]string)
	}

	type AssociationsResponse struct {
		Success      bool              `json:"success"`
		Associations map[string]string `json:"associations,omitempty"`
		Error        string            `json:"error,omitempty"`
	}

	assocResponse := AssociationsResponse{
		Success:      true,
		Associations: associationsToSend,
	}

	jsonResponse, err := json.Marshal(assocResponse)
	if err != nil {
		return
	}

	err = replier.SendMessage(CERTIFICATE_SELECT_RESPONSE, string(jsonResponse))
	if err != nil {
	}
}

// handleCertificateSelectResponse handles the certificate selection response from frontend
func (b *GeminiBackend) handleCertificateSelectResponse(replier *BackendReplier, content string) {
	var resp CertificateSelectResponse
	if err := json.Unmarshal([]byte(content), &resp); err != nil {
		return
	}

	// Parse the URL to extract the domain
	parsedURL, err := url.Parse(resp.URL)
	if err != nil {
		return
	}

	domain := parsedURL.Hostname()

	// Store the certificate association
	if err := b.certificateManager.SetCertificateForDomain(domain, resp.CertificateId); err != nil {
		return
	}

	// Notify frontend that certificate association has been updated
	// Send message type 607 with the full associations list
	associations, err := b.certificateManager.ListAssociations()
	if err != nil {
		return
	}

	type AssociationsResponse struct {
		Success      bool              `json:"success"`
		Associations map[string]string `json:"associations,omitempty"`
		Error        string            `json:"error,omitempty"`
	}

	assocResponse := AssociationsResponse{
		Success:      true,
		Associations: associations,
	}

	jsonResponse, err := json.Marshal(assocResponse)
	if err != nil {
		return
	}

	err = replier.SendMessage(CERTIFICATE_SELECT_RESPONSE, string(jsonResponse))
	if err != nil {
	}
}

// sendCertificateResponse sends a certificate response to the frontend
func (b *GeminiBackend) sendCertificateResponse(replier *BackendReplier, response CertificateResponse) {
	jsonResponse, err := json.Marshal(response)
	if err != nil {
		return
	}

	err = replier.SendMessage(CERTIFICATE_RESPONSE, string(jsonResponse))
	if err != nil {
	}
}

// mapRefreshMode maps string refresh mode values to integer constants for qtfb
// Based on constants in rm-appload/src/qtfb/common.h:
// REFRESH_MODE_UFAST = 0
// REFRESH_MODE_FAST = 1
// REFRESH_MODE_ANIMATE = 2
// REFRESH_MODE_CONTENT = 3
// REFRESH_MODE_UI = 4
func (b *GeminiBackend) mapRefreshMode(mode string) int {
	switch strings.TrimSpace(strings.ToLower(mode)) {
	case "quality":
		return 3 // REFRESH_MODE_CONTENT
	case "fast":
		return 1 // REFRESH_MODE_FAST
	case "animate":
		return 2 // REFRESH_MODE_ANIMATE
	case "ui":
		return 4 // REFRESH_MODE_UI
	case "ufast":
		return 0 // REFRESH_MODE_UFAST
	default:
		// Default to UI mode for unrecognized values
		return 4 // REFRESH_MODE_UI
	}
}

// handleListCertificateAssociations handles listing all certificate associations
func (b *GeminiBackend) handleListCertificateAssociations(replier *BackendReplier) {
	associations, err := b.certificateManager.ListAssociations()
	if err != nil {
		response := CertificateResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to load certificate associations: %v", err),
		}
		b.sendCertificateResponse(replier, response)
		return
	}

	// We need to send the associations in a way the frontend can understand
	// The frontend expects a map where keys are domains and values are certificate IDs
	type AssociationsResponse struct {
		Success      bool            `json:"success"`
		Associations map[string]string `json:"associations,omitempty"`
		Error        string          `json:"error,omitempty"`
	}

	assocResponse := AssociationsResponse{
		Success:      true,
		Associations: associations,
	}

	jsonResponse, err := json.Marshal(assocResponse)
	if err != nil {
		return
	}

	err = replier.SendMessage(CERTIFICATE_SELECT_RESPONSE, string(jsonResponse))
	if err != nil {
	}
}

// sendInputRequest sends an input request to the frontend
func (b *GeminiBackend) sendInputRequest(replier *BackendReplier, geminiURL, prompt string, sensitive bool) {
	request := InputRequest{
		Prompt:    prompt,
		Sensitive: sensitive,
		URL:       geminiURL,
	}

	jsonRequest, err := json.Marshal(request)
	if err != nil {
		b.sendError(replier, geminiURL, "Failed to create input request")
		return
	}

	err = replier.SendMessage(INPUT_REQUEST, string(jsonRequest))
	if err != nil {
	}
}

// sendCertificateSelectRequest sends a certificate selection request to the frontend
func (b *GeminiBackend) sendCertificateSelectRequest(replier *BackendReplier, geminiURL, prompt, meta string) {
	// Get list of available certificates
	certificates, err := b.certificateManager.ListCertificates()
	if err != nil {
		b.sendError(replier, geminiURL, fmt.Sprintf("Certificate required: %s - %s", prompt, meta))
		return
	}

	request := CertificateSelectRequest{
		Prompt:       prompt,
		Meta:         meta,
		URL:          geminiURL,
		Certificates: certificates,
	}

	jsonRequest, err := json.Marshal(request)
	if err != nil {
		b.sendError(replier, geminiURL, fmt.Sprintf("Certificate required: %s - %s", prompt, meta))
		return
	}

	err = replier.SendMessage(CERTIFICATE_SELECT, string(jsonRequest))
	if err != nil {
		b.sendError(replier, geminiURL, fmt.Sprintf("Certificate required: %s - %s", prompt, meta))
	}
}

// handleSaveSettings handles saving updated settings
func (b *GeminiBackend) handleSaveSettings(replier *BackendReplier, content string) {
	// Parse content as JSON settings object
	var newSettings Settings
	if err := json.Unmarshal([]byte(content), &newSettings); err != nil {
		response := SettingsResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to parse settings data: %v", err),
		}
		b.sendSettingsResponse(replier, response)
		return
	}

	// Load current settings to preserve bookmarks and other data not managed by frontend
	currentSettings, err := b.settingsManager.LoadSettings()
	if err != nil {
		response := SettingsResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to load current settings: %v", err),
		}
		b.sendSettingsResponse(replier, response)
		return
	}

	// Update only the settings that are managed by the frontend
	// Preserve bookmarks as they're managed separately
	currentSettings.Padding = newSettings.Padding
	currentSettings.TextSize = newSettings.TextSize
	currentSettings.Homepage = newSettings.Homepage
	currentSettings.ProxyURL = newSettings.ProxyURL
	currentSettings.ProxyPort = newSettings.ProxyPort
	currentSettings.RefreshMode = newSettings.RefreshMode

	// Save updated settings
	if err := b.settingsManager.SaveSettings(currentSettings); err != nil {
		response := SettingsResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to save settings: %v", err),
		}
		b.sendSettingsResponse(replier, response)
		return
	}

	// Send success response with updated settings
	response := SettingsResponse{
		Success:  true,
		Settings: currentSettings,
	}
	b.sendSettingsResponse(replier, response)
}

// handleGetSettings handles getting current settings
func (b *GeminiBackend) handleGetSettings(replier *BackendReplier) {
	settings, err := b.settingsManager.LoadSettings()
	if err != nil {
		response := SettingsResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to load settings: %v", err),
		}
		b.sendSettingsResponse(replier, response)
		return
	}

	// Create a copy of settings without scaleFactor (frontend-only property)
	settingsToSend := Settings{
		Padding:      settings.Padding,
		TextSize:     settings.TextSize,
		Homepage:     settings.Homepage,
		Bookmarks:    settings.Bookmarks,
		BypassedURLs: settings.BypassedURLs,
		ProxyURL:     settings.ProxyURL,
		ProxyPort:    settings.ProxyPort,
		RefreshMode:  settings.RefreshMode,
	}

	response := SettingsResponse{
		Success:  true,
		Settings: settingsToSend,
	}
	b.sendSettingsResponse(replier, response)
}


// sendSettingsResponse sends a settings response to the frontend
func (b *GeminiBackend) sendSettingsResponse(replier *BackendReplier, response SettingsResponse) {
	jsonResponse, err := json.Marshal(response)
	if err != nil {
		return
	}

	err = replier.SendMessage(SETTINGS_RESPONSE, string(jsonResponse))
	if err != nil {
	}
}

// fetchGeminiPageWithRedirectCount retrieves content from a Gemini URL with redirect loop protection
func (b *GeminiBackend) fetchGeminiPageWithRedirectCount(replier *BackendReplier, geminiURL string, redirectCount int) {
	// Check for redirect loops (max 5 redirects as per Gemini spec)
	if redirectCount >= 5 {
		b.sendError(replier, geminiURL, "Too many redirects (max 5)")
		return
	}
	// Validate and parse the URL
	parsedURL, err := url.Parse(geminiURL)
	if err != nil {
		b.sendError(replier, geminiURL, fmt.Sprintf("Invalid URL: %v", err))
		return
	}

	// Check if this is an HTTP/HTTPS URL and we have a proxy configured
	settings, _ := b.settingsManager.LoadSettings()
	isProxyConfigured := settings.ProxyURL != "" && settings.ProxyPort > 0

	if parsedURL.Scheme != "gemini" && parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
		b.sendError(replier, geminiURL, "URL must use gemini://, http://, or https:// scheme")
		return
	}

	// For HTTP/HTTPS URLs, we need a proxy to translate them to Gemini
	if (parsedURL.Scheme == "http" || parsedURL.Scheme == "https") && !isProxyConfigured {
		b.sendError(replier, geminiURL, "HTTP/HTTPS URLs require a proxy to be configured in Settings")
		return
	}

	// Special case for localhost testing
	if parsedURL.Hostname() == "localhost" || parsedURL.Hostname() == "127.0.0.1" {
		// For testing purposes, serve our local test file
		if parsedURL.Path == "/test-links.gmi" {
			content, err := os.ReadFile("test-links.gmi")
			if err != nil {
				b.sendError(replier, geminiURL, fmt.Sprintf("Failed to read test file: %v", err))
				return
			}
			b.sendResponse(replier, geminiURL, string(content))
			return
		}
	}

	// Check if there's a certificate associated with this domain
	fingerprint, err := b.certificateManager.GetCertificateForDomain(parsedURL.Hostname())
	var certificates []tls.Certificate
	if err == nil && fingerprint != "" {
		// Load the certificate by its fingerprint
		cert, err := b.loadCertificateByFingerprint(fingerprint)
		if err == nil {
			certificates = []tls.Certificate{cert}
		}
	}

	// Create TLS connection
	// For Gemini protocol, we need to handle self-signed certificates properly
	// Many Gemini servers use self-signed certificates, which is acceptable in this protocol
	// We'll implement proper certificate verification that allows self-signed certs
	config := &tls.Config{
		InsecureSkipVerify: true, // We'll do our own verification
		ServerName:         parsedURL.Hostname(),
		NextProtos:         []string{"gemini"},
		Certificates:       certificates, // Use client certificate if available
		VerifyPeerCertificate: func(rawCerts [][]byte, verifiedChains [][]*x509.Certificate) error {
			// Parse the certificate
			if len(rawCerts) == 0 {
				return fmt.Errorf("no certificates provided")
			}

			cert, err := x509.ParseCertificate(rawCerts[0])
			if err != nil {
				return fmt.Errorf("failed to parse certificate: %v", err)
			}

			// For Gemini, we accept self-signed certificates as valid
			// We're not trying to verify the identity of the server, just establish a secure connection
			// The actual security comes from the user verifying the certificate fingerprint out-of-band
			// This is the standard approach in the Gemini protocol

			// Check if certificate validation should be bypassed for this URL
			if b.isBypassedURL(geminiURL) {
				// Bypass certificate validation
				return nil
			}

			// Check basic certificate validity (not expired, etc.)
			// But don't enforce strict hostname verification as many Gemini servers
			// use legacy certificates with CN only
			currentTime := time.Now()
			if currentTime.Before(cert.NotBefore) {
				return fmt.Errorf("certificate not yet valid")
			}
			if currentTime.After(cert.NotAfter) {
				return fmt.Errorf("certificate has expired")
			}

			// Certificate is valid - in Gemini protocol, this is sufficient
			// Hostname verification is optional and often fails with self-signed certs
			return nil
		},
	}

	var conn *tls.Conn
	var targetHost string

	if (parsedURL.Scheme == "http" || parsedURL.Scheme == "https") && isProxyConfigured {
		// Use proxy for HTTP/HTTPS URLs
		targetHost = fmt.Sprintf("%s:%d", settings.ProxyURL, settings.ProxyPort)
		// For HTTP/HTTPS URLs via proxy, we need to modify how the request is sent
		// The proxy should receive the original URL as part of the request
	} else {
		// Direct connection for Gemini URLs or when no proxy is needed
		targetHost = parsedURL.Host + ":1965"
	}

	// Establish connection
	conn, err = tls.DialWithDialer(&net.Dialer{Timeout: 10 * time.Second}, "tcp", targetHost, config)
	if err != nil {
		// Check if this is a certificate expiration error
		errStr := err.Error()
		if strings.Contains(errStr, "certificate has expired") {
			// Send certificate expired message to frontend
			b.sendCertificateExpired(replier, geminiURL, errStr)
			return
		}
		b.sendError(replier, geminiURL, fmt.Sprintf("Connection failed: %v", err))
		return
	}
	defer conn.Close()

	// Send request
	var request string
	if (parsedURL.Scheme == "http" || parsedURL.Scheme == "https") && isProxyConfigured {
		// For HTTP/HTTPS URLs via proxy, send the original URL as the request
		// The proxy should understand this format
		request = geminiURL + "\r\n"
	} else {
		// For direct Gemini connections, send the URL as normal
		request = geminiURL + "\r\n"
	}
	_, err = conn.Write([]byte(request))
	if err != nil {
		b.sendError(replier, geminiURL, fmt.Sprintf("Failed to send request: %v", err))
		return
	}

	// Read response
	response, err := io.ReadAll(conn)
	if err != nil {
		b.sendError(replier, geminiURL, fmt.Sprintf("Failed to read response: %v", err))
		return
	}

	if len(response) < 3 {
		b.sendError(replier, geminiURL, "Invalid response from server")
		return
	}

	// Parse status line
	statusLine := strings.TrimSpace(string(response[:3]))
	// Keep raw content for binary data handling
	rawContent := response[3:]
	content := string(rawContent)

	// Handle redirects (status codes starting with 3)
	if strings.HasPrefix(statusLine, "3") {
		// Handle redirect by following it
		redirectURL := strings.TrimSpace(content)

		// Resolve relative URLs
		if !strings.HasPrefix(redirectURL, "gemini://") {
			// Handle relative redirects
			baseURL, err := url.Parse(geminiURL)
			if err != nil {
				b.sendError(replier, geminiURL, fmt.Sprintf("Failed to parse base URL for redirect: %v", err))
				return
			}

			redirectURLParsed, err := baseURL.Parse(redirectURL)
			if err != nil {
				b.sendError(replier, geminiURL, fmt.Sprintf("Failed to resolve relative redirect URL: %v", err))
				return
			}

			redirectURL = redirectURLParsed.String()
		}

		// Follow the redirect by making a new request with incremented redirect count
		b.fetchGeminiPageWithRedirectCount(replier, redirectURL, redirectCount+1)
		return
	}

	// Handle different status codes
	switch statusLine {
	case "10":
		// Input required
		b.sendInputRequest(replier, geminiURL, content, false)
		return
	case "11":
		// Sensitive input required
		b.sendInputRequest(replier, geminiURL, content, true)
		return
	case "20":
		// Success - text/gemini or other content types
		// Check if the first line indicates an image MIME type
		lines := strings.Split(content, "\n")
		if len(lines) > 0 {
			firstLine := strings.TrimSpace(lines[0])
			if strings.HasPrefix(firstLine, "image/") {
				// Handle image content with raw binary data
				// Find the position of the first newline to separate MIME type from data
				firstNewline := bytes.IndexByte(rawContent, '\n')
				if firstNewline != -1 && firstNewline < len(rawContent)-1 {
					imageData := rawContent[firstNewline+1:]
					// Convert to base64 for safe transmission
					encodedData := base64.StdEncoding.EncodeToString(imageData)
					b.handleImageContent(replier, geminiURL, firstLine, encodedData)
				} else {
					// No data after MIME type line
					b.handleImageContent(replier, geminiURL, firstLine, "")
				}
				return
			}
			// Filter out MIME type line if present (first line containing ";" or "text/gemini")
			if strings.Contains(lines[0], ";") || strings.Contains(strings.ToLower(lines[0]), "text/gemini") {
				// Remove the first line (MIME type)
				content = strings.Join(lines[1:], "\n")
			}
		}
		b.sendResponse(replier, geminiURL, content)
	case "21":
		// Success - other MIME type (including images)
		// Check if this is an image by examining the first line (MIME type)
		lines := strings.Split(content, "\n")
		if len(lines) > 0 {
			mimeType := strings.TrimSpace(lines[0])

			// Check if this is an image MIME type
			if strings.HasPrefix(mimeType, "image/") {
				// Handle image content with raw binary data
				// Find the position of the first newline to separate MIME type from data
				firstNewline := bytes.IndexByte(rawContent, '\n')
				if firstNewline != -1 && firstNewline < len(rawContent)-1 {
					imageData := rawContent[firstNewline+1:]
					// Convert to base64 for safe transmission
					encodedData := base64.StdEncoding.EncodeToString(imageData)
					b.handleImageContent(replier, geminiURL, mimeType, encodedData)
				} else {
					// No data after MIME type line
					b.handleImageContent(replier, geminiURL, mimeType, "")
				}
				return
			}
		}
		// For other binary content, send a notification
		b.sendResponse(replier, geminiURL, "[Binary content - not displaying]")
	case "60":
		// Client certificate required
		b.sendCertificateSelectRequest(replier, geminiURL, "Client certificate required", content)
	case "61":
		// Temporary certificate required
		b.sendCertificateSelectRequest(replier, geminiURL, "Temporary certificate required", content)
	case "62":
		// Authorized certificate required
		b.sendCertificateSelectRequest(replier, geminiURL, "Authorized certificate required", content)
	default:
		// Error status
		b.sendError(replier, geminiURL, fmt.Sprintf("Server returned status %s: %s", statusLine, content))
	}
}

// sendResponse sends a successful response to the frontend
func (b *GeminiBackend) sendResponse(replier *BackendReplier, url, content string) {
	response := GeminiResponse{
		Success: true,
		URL:     url,
		Content: content,
	}

	jsonResponse, err := json.Marshal(response)
	if err != nil {
		return
	}

	err = replier.SendMessage(GEMINI_RESPONSE, string(jsonResponse))
	if err != nil {
	}
}

// sendError sends an error response to the frontend
func (b *GeminiBackend) sendError(replier *BackendReplier, url, errorMsg string) {
	response := GeminiResponse{
		Success: false,
		URL:     url,
		Error:   errorMsg,
	}

	jsonResponse, err := json.Marshal(response)
	if err != nil {
		return
	}

	err = replier.SendMessage(GEMINI_RESPONSE, string(jsonResponse))
	if err != nil {
	}
}

// sendCertificateExpired sends a certificate expired notification to the frontend
func (b *GeminiBackend) sendCertificateExpired(replier *BackendReplier, url, errorMsg string) {
	response := GeminiResponse{
		Success: false,
		URL:     url,
		Error:   errorMsg,
	}

	jsonResponse, err := json.Marshal(response)
	if err != nil {
		return
	}

	err = replier.SendMessage(CERTIFICATE_EXPIRED, string(jsonResponse))
	if err != nil {
	}
}

// addBypassedURL adds a URL to the bypassed URLs list and saves it to settings
func (b *GeminiBackend) addBypassedURL(url string) {
	b.bypassedURLsMutex.Lock()
	defer b.bypassedURLsMutex.Unlock()
	b.bypassedURLs[url] = true

	// Also save to settings for persistence
	// Load current settings
	settings, err := b.settingsManager.LoadSettings()
	if err != nil {
		return
	}

	// Check if URL is already in the list
	for _, existingURL := range settings.BypassedURLs {
		if existingURL == url {
			return // Already in the list
		}
	}

	// Add to the list and save
	settings.BypassedURLs = append(settings.BypassedURLs, url)
	if err := b.settingsManager.SaveSettings(settings); err != nil {
	}
}

// isBypassedURL checks if a URL is in the bypassed URLs list
// First checks in-memory cache, then checks settings file
func (b *GeminiBackend) isBypassedURL(url string) bool {
	// Check in-memory cache first
	b.bypassedURLsMutex.RLock()
	if bypassed, exists := b.bypassedURLs[url]; exists {
		b.bypassedURLsMutex.RUnlock()
		return bypassed
	}
	b.bypassedURLsMutex.RUnlock()

	// Check settings file
	settings, err := b.settingsManager.LoadSettings()
	if err != nil {
		return false
	}

	for _, bypassedURL := range settings.BypassedURLs {
		if bypassedURL == url {
			// Add to in-memory cache for faster future checks
			b.bypassedURLsMutex.Lock()
			b.bypassedURLs[url] = true
			b.bypassedURLsMutex.Unlock()
			return true
		}
	}

	return false
}

// ImageResponse represents an image response structure sent to the frontend
type ImageResponse struct {
	Success   bool   `json:"success"`
	URL       string `json:"url"`
	ImagePath string `json:"imagePath"`
	MimeType  string `json:"mimeType"`
	Error     string `json:"error,omitempty"`
	// IsInline indicates if this is an inline image (displayed in content flow)
	IsInline bool `json:"isInline"`
}

// handleImageContent processes binary image content by saving it to a temporary file
// and sending a reference to the frontend
func (b *GeminiBackend) handleImageContent(replier *BackendReplier, geminiURL, mimeType, imageData string) {
	// Create a temporary file for the image
	tmpFile, err := ioutil.TempFile("", "gemini-image-*.tmp")
	if err != nil {
		b.sendImageError(replier, geminiURL, fmt.Sprintf("Failed to create temp file for image: %v", err))
		return
	}
	defer tmpFile.Close()

	// For images, the imageData is base64 encoded
	if imageData != "" {
		// Decode base64 data
		decodedData, err := base64.StdEncoding.DecodeString(imageData)
		if err != nil {
			os.Remove(tmpFile.Name()) // Clean up the temp file
			b.sendImageError(replier, geminiURL, fmt.Sprintf("Failed to decode image data: %v", err))
			return
		}

		// Write decoded binary data to file
		_, err = tmpFile.Write(decodedData)
		if err != nil {
			os.Remove(tmpFile.Name()) // Clean up the temp file
			b.sendImageError(replier, geminiURL, fmt.Sprintf("Failed to write image data: %v", err))
			return
		}
	}

	// Send a special image response to the frontend
	response := ImageResponse{
		Success:   true,
		URL:       geminiURL,
		ImagePath: tmpFile.Name(),
		MimeType:  mimeType,
		IsInline:  true, // Mark as inline image response
	}

	jsonResponse, err := json.Marshal(response)
	if err != nil {
		os.Remove(tmpFile.Name()) // Clean up the temp file
		b.sendImageError(replier, geminiURL, fmt.Sprintf("Failed to prepare image response: %v", err))
		return
	}

	err = replier.SendMessage(INLINE_IMAGE_RESPONSE, string(jsonResponse))
	if err != nil {
		os.Remove(tmpFile.Name()) // Clean up the temp file
	}
}

// sendImageError sends an error response specifically for image handling
func (b *GeminiBackend) sendImageError(replier *BackendReplier, url, errorMsg string) {
	response := ImageResponse{
		Success: false,
		URL:     url,
		Error:   errorMsg,
	}

	jsonResponse, err := json.Marshal(response)
	if err != nil {
		return
	}

	err = replier.SendMessage(GEMINI_RESPONSE, string(jsonResponse))
	if err != nil {
	}
}

func main() {
	if len(os.Args) < 2 {
		os.Exit(1)
	}

	socketPath := os.Args[1]

	// Initialize certificate manager
	certificateManager, err := NewCertificateManager()
	if err != nil {
		os.Exit(1)
	}

	// Initialize settings manager
	settingsManager, err := NewSettingsManager()
	if err != nil {
		os.Exit(1)
	}

	backend := &GeminiBackend{
		certificateManager: certificateManager,
		settingsManager:    settingsManager,
		bypassedURLs:       make(map[string]bool),
	}

	app, err := NewAppLoad(socketPath, backend)
	if err != nil {
		os.Exit(1)
	}
	defer app.Close()

	err = app.Run()
	if err != nil {
	}
}