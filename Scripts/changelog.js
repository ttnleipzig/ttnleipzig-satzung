const {execSync} = require('child_process')
const fs = require('fs')
const path = require('path')
const axios = require('axios')
const yargs = require('yargs')

// OpenAI API constants
const openAIURL = 'https://api.openai.com/v1/chat/completions'
const openAIModel = 'gpt-4'

// OpenAI API key from environment variables
const openAIAPIKey = process.env.OPENAI_API_KEY

// Struct for translations
const translations = {}

// Load translations
function loadTranslations(lang) {
    const filePath = path.join(__dirname, 'Translations', `${lang}.json`)
    const data = fs.readFileSync(filePath, 'utf8')
    Object.assign(translations, JSON.parse(data))
}

// Create changelog header
function createChangelogHeader(changelogFile) {
    const header = `# Changelog\n\n${translations.ChangelogHeader}\n\n`
    fs.writeFileSync(changelogFile, header, 'utf8')
}

// Append to changelog
function appendToChangelog(changelogFile, content) {
    fs.appendFileSync(changelogFile, content, 'utf8')
}

// Get Git tags
function getGitTags() {
    const output = execSync('git tag --sort=v:refname').toString()
    const tags = output.trim().split('\n')
    return tags.reverse()
}

// Get tag date
function getTagDate(tag) {
    const output = execSync(`git log -1 --format=%ai ${tag}`).toString()
    return output.trim().split(' ')[0]
}

// Get commits for tag
function getCommitsForTag(tag) {
    const output = execSync(`git log ${tag}^..${tag} --pretty=format:%B`).toString()
    return output.trim().split('\n\n')
}

// Get commits between tags
function getCommitsBetweenTags(oldTag, newTag) {
    const output = execSync(`git log ${oldTag}..${newTag} --pretty=format:%B`).toString()
    return output.trim().split('\n\n')
}

// Check if commit is semantic
function isSemanticCommit(commit) {
    return ['feat', 'fix', 'docs', 'chore', 'refactor', 'style', 'test'].some(prefix => commit.startsWith(prefix))
}

// Get commit type
function getCommitType(commit) {
    const parts = commit.split(':', 2)
    if (parts.length > 0) {
        let commitType = parts[0]
        if (commitType.includes('(')) {
            commitType = commitType.split('(')[0]
        }
        return commitType
    }
    return 'unknown'
}

// Translate commit type
function translateCommitType(commitType) {
    switch (commitType) {
        case 'feat':
            return translations.Feat
        case 'fix':
            return translations.Fix
        case 'docs':
            return translations.Docs
        case 'chore':
            return translations.Chore
        case 'refactor':
            return translations.Refactor
        case 'style':
            return translations.Style
        case 'test':
            return translations.Test
        default:
            return 'Unknown'
    }
}

// Translate to simple language
async function translateToSimpleLanguage(text, lang) {
    if (!openAIAPIKey) {
        throw new Error('Error: No OpenAI API key found. Set OPENAI_API_KEY.')
    }

    // Remove the prefix before translation
    const parts = text.split(':', 2)
    if (parts.length > 1) {
        text = parts[1].trim()
    }

    const systemPrompt = `You are a translator who translates semantic commit messages into simple ${lang}. Write as if the command has already been executed.`

    const request = {
        model: openAIModel,
        max_tokens: 100,
        temperature: 0.5,
        messages: [
            {role: 'system', content: systemPrompt},
            {role: 'user', content: text}
        ]
    }

    const response = await axios.post(openAIURL, request, {
        headers: {
            'Authorization': `Bearer ${openAIAPIKey}`,
            'Content-Type': 'application/json'
        }
    })

    return response.data.choices[0].message.content
}

// Main function
async function main() {
    const argv = yargs
        .option('lang', {
            alias: 'l',
            description: 'Language for translations (e.g., en, de, es, fr, it, ja, pt, zh)',
            type: 'string',
            default: 'en'
        })
        .option('file', {
            alias: 'f',
            description: 'Name of the changelog file',
            type: 'string',
            default: 'CHANGELOG.md'
        })
        .help()
        .alias('help', 'h')
        .argv

    const lang = argv.lang
    const changelogFile = argv.file

    // Load translations
    loadTranslations(lang)

    // Create changelog header
    createChangelogHeader(changelogFile)

    // Retrieve and reverse Git tags
    const tags = getGitTags()

    // Iterate over each Git tag
    for (let i = 0; i < tags.length; i++) {
        let commits
        let date

        if (i === tags.length - 1) {
            // Retrieve commits for the first tag
            commits = getCommitsForTag(tags[i])
            date = getTagDate(tags[i])
        } else {
            // Retrieve commits between tags
            commits = getCommitsBetweenTags(tags[i + 1], tags[i])
            date = getTagDate(tags[i])
        }

        if (commits.length === 0) {
            console.log(translations.NoCommitsMessage, tags[i])
            continue
        }

        appendToChangelog(changelogFile, `## [${tags[i]}] - ${date}\n`)

        const semanticGroups = {}

        for (const commit of commits) {
            if (isSemanticCommit(commit)) {
                const group = getCommitType(commit)
                const translatedCommit = await translateToSimpleLanguage(commit, lang)
                const translatedGroup = translateCommitType(group)
                if (!semanticGroups[translatedGroup]) {
                    semanticGroups[translatedGroup] = []
                }
                semanticGroups[translatedGroup].push(translatedCommit)
            }
        }

        // Insert commit groupings into the changelog file
        for (const [group, messages] of Object.entries(semanticGroups)) {
            appendToChangelog(changelogFile, `\n### ${group}\n\n`)
            for (const message of messages) {
                const lines = message.split('\n')
                for (const line of lines) {
                    if (line.trim() !== '') {
                        appendToChangelog(changelogFile, `- ${line}\n`)
                    }
                }
            }
        }

        appendToChangelog(changelogFile, '\n')
    }

    console.log(translations.ChangelogCreated, changelogFile)
}

main().catch(err => {
    console.error(err)
    process.exit(1)
})
