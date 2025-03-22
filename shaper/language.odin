package rune
// TODO: move to ttf??
// Table Near Bottom has lange tags
// https://learn.microsoft.com/en-us/typography/script-development/standard
Language_Tag :: enum {
	// Default language system (used when no language is specified)
	dflt, // Default language system

	// Arabic script languages
	ARA, // Arabic
	URD, // Urdu
	SND, // Sindhi
	KSH, // Kashmiri
	MLY, // Malay
	PAS, // Pashto
	SHI, // Sindhi

	// Armenian script languages
	HYE, // Armenian

	// Bengali script languages
	BEN, // Bengali
	ASM, // Assamese

	// Cyrillic script languages
	RUS, // Russian
	SRB, // Serbian
	BGR, // Bulgarian
	UKR, // Ukrainian
	BLR, // Belarusian
	MKD, // Macedonian

	// Devanagari script languages
	HIN, // Hindi
	MAR, // Marathi
	NEP, // Nepali
	SAN, // Sanskrit
	KOK, // Konkani

	// Greek script languages
	ELL, // Greek

	// Gujarati script languages
	GUJ, // Gujarati

	// Gurmukhi script languages
	PAN, // Punjabi

	// Han script languages
	ZHS, // Chinese (Simplified)
	ZHT, // Chinese (Traditional)
	ZHP, // Chinese (Hong Kong)

	// Hebrew script languages
	IWR, // Hebrew
	JII, // Yiddish

	// Japanese
	JAN, // Japanese

	// Kannada script languages
	KAN, // Kannada

	// Korean script languages
	KOR, // Korean

	// Latin script languages
	ENG, // English
	FRA, // French
	DEU, // German
	ITA, // Italian
	NLD, // Dutch
	SVE, // Swedish
	ESP, // Spanish
	POR, // Portuguese
	CAT, // Catalan
	DAN, // Danish
	NOR, // Norwegian
	FIN, // Finnish
	ISL, // Icelandic
	TRK, // Turkish
	POL, // Polish
	CSY, // Czech
	SKY, // Slovak
	HUN, // Hungarian
	ROM, // Romanian
	EST, // Estonian
	LVI, // Latvian
	LTH, // Lithuanian
	IRL, // Irish
	MTS, // Maltese
	SQI, // Albanian
	SLO, // Slovenian
	HRV, // Croatian

	// Malayalam script languages
	MAL, // Malayalam

	// Oriya script languages
	ORI, // Oriya

	// Tamil script languages
	TAM, // Tamil

	// Telugu script languages
	TEL, // Telugu

	// Thai script languages
	THA, // Thai

	// Tibetan script languages
	TIB, // Tibetan

	// Other languages
	VIT, // Vietnamese
	ETI, // Estonian
	LAO, // Lao
	KHM, // Khmer
	MYA, // Burmese
	KAZ, // Kazakh
	UZB, // Uzbek
	KIR, // Kirghiz
	TUK, // Turkmen
	AZE, // Azerbaijani
	MON, // Mongolian

	// More recent additions
	AFR, // Afrikaans
	FAR, // Farsi/Persian
	GAE, // Gaelic
	HAL, // Hausa
	JAV, // Javanese
	MLT, // Maltese
	MOL, // Moldavian
	SWA, // Swahili
	TGL, // Tagalog
	WAL, // Welsh
	YID, // Yiddish
}
