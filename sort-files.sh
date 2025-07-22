#!/bin/bash

# File Sorter Script for macOS
# Usage: ./file_sorter.sh [--dry-run] [--verbose]

set -euo pipefail

# Configuration
DRY_RUN=false
VERBOSE=false
SECONDS=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-d|-dv)
            DRY_RUN=true
            VERBOSE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--verbose]"
            echo "  --dry-run, -d    Show what would be moved without actually moving files"
            echo "  --verbose, -v    Show detailed output"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Source directories to scan
SOURCE_DIRS=(
    "$HOME/Desktop"
    "$HOME/Downloads" 
    "$HOME/Documents"
    "$HOME/Pictures"
    "$HOME/Movies"
    "$HOME/Music"
)

# Target directories
MEDIA_DIR="$HOME/Media"
ARCHIVE_DIR="$HOME/Archive"
DOCS_DIR="$HOME/Docs"
THREED_DIR="$HOME/3D"

# Patterns to ignore (supports wildcards)
IGNORE_LIST=(
    "dont_move_me.txt"
    ".tmp"
    ".crdownload"
    "*.part"
    ".DS_Store"
    "Thumbs.db"
    "iTunes"
    "Music Library.musiclibrary"
    "*.musiclibrary"
    "System"
    "Library"
    ".Trash"
    "Applications"
    ".localized"
)

# Screenshot filename patterns
SCREENSHOT_PATTERNS=(
    "Screen Shot *.png"
    "Screenshot *.png"
    "CleanShot *.png"
    "Monosnap *.png"
)

# Color codes for output
RED='\033[38;5;9m'
GREEN='\033[38;5;28m'
YELLOW='\033[38;5;220m'
BLUE='\033[38;5;33m'
DARKBLUE='\033[38;5;123m'
PURPLE='\033[38;5;99m'
ORANGE='\033[38;5;209m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

should_ignore() {
    local file="$1"
    local basename=$(basename "$file")

    for pattern in "${IGNORE_LIST[@]}"; do
        if [[ "$basename" == $pattern ]]; then
            if [[ "$basename" != ".localized" && "$basename" != ".DS_Store" ]]; then
                log_info "${YELLOW}Ignoring: $basename (matches pattern: $pattern)"
            fi
            return 0
        fi
    done

    # Special case: ignore Music app folder in Music directory
    if [[ "$file" == "$HOME/Music/Music" ]] && [[ -d "$file" ]]; then
        log_info "Ignoring Music app folder: $file"
        return 0
    fi

    return 1
}

# Function to check if file is a screenshot
is_screenshot() {
    local file="$1"
    local basename=$(basename "$file")
    
    for pattern in "${SCREENSHOT_PATTERNS[@]}"; do
        if [[ "$basename" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Function to create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "Would create directory: $dir"
        else
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        fi
    fi
}

# Function to move file
move_file() {
    local source="$1"
    local target_dir="$2"
    local filename=$(basename "$source")
    local target="$target_dir/$filename"
    
    ensure_dir "$target_dir"
    
    # Handle filename conflicts
    local counter=1
    local base_name="${filename%.*}"
    local extension="${filename##*.}"
    
    # If there's no extension, treat the whole name as base
    if [[ "$base_name" == "$extension" ]]; then
        extension=""
    fi
    
    while [[ -e "$target" ]]; do
        if [[ -n "$extension" ]]; then
            target="$target_dir/${base_name}_${counter}.${extension}"
        else
            target="$target_dir/${filename}_${counter}"
        fi
        ((counter++))
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would move: $source -> $target"
    else
        mv "$source" "$target"
        log_success "Moved: $source -> $target"
    fi
}

# Function to determine target directory based on file extension and content
get_target_directory() {
    local file="$1"
    local extension="${file##*.}"
    extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
    local basename=$(basename "$file")
    local dirname=$(dirname "$file")
    
    # Check if it's a screenshot first
    if is_screenshot "$file"; then
        echo "$MEDIA_DIR/Screenshots"
        return
    fi
    
    # Check for Camera files (.raw or folders with CANON)
    if [[ "$extension" == "raw" ]] || [[ -d "$file" && "$basename" == *"CANON"* ]]; then
        echo "$MEDIA_DIR/Camera"
        return
    fi
    
    case "$extension" in
        # Audio files
        mp3|wav|flac|aac|ogg|m4a|wma|aiff|au)
            echo "$MEDIA_DIR/Audio"
            ;;
        
        # Photo files
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif|svg)
            # Skip if it's a screenshot (already handled above)
            if ! is_screenshot "$file"; then
                echo "$MEDIA_DIR/Photos"
            fi
            ;;
        
        # Video files
        mp4|avi|mkv|mov|wmv|flv|webm|m4v|3gp|mpg|mpeg|ogv)
            echo "$MEDIA_DIR/Video"
            ;;
        
        # Shop files (Design/Photo editing)
        psd|pxd|ai|sketch|fig|xd|indd|lrcat|lrtemplate)
            echo "$MEDIA_DIR/Shop"
            ;;
        
        # Compressed files
        zip|rar|7z|tar|gz|bz2|xz|z)
            echo "$ARCHIVE_DIR/Compressed"
            ;;
        
        # Disk images
        dmg|iso|img|bin|cue|pkg)
            echo "$ARCHIVE_DIR/DiskImages"
            ;;
        
        # 3D files
        stl|ply|step|stp|iges|igs|sat|brep)
            echo "$THREED_DIR/CAD"
            ;;
        dxf|dwg)
            echo "$THREED_DIR/Drawings"
            ;;
        obj|3ds|fbx|dae|blend|max|ma|mb)
            echo "$THREED_DIR/Objects"
            ;;
        gcode|x3g|3mf)
            echo "$THREED_DIR/Prints"
            ;;
        
        # Document files - Text
        txt|md|rtf|tex)
            echo "$DOCS_DIR/Text"
            ;;
        doc|docx|pages|odt)
            echo "$DOCS_DIR/Docs"
            ;;
        
        # Document files - Presentations
        ppt|pptx|key|odp)
            echo "$DOCS_DIR/Slides"
            ;;
        
        # Document files - PDFs
        pdf)
            echo "$DOCS_DIR/Pdf"
            ;;
        
        # Document files - Spreadsheets
        xls|xlsx|numbers|ods|csv)
            echo "$DOCS_DIR/Sheets"
            ;;
        
        *)
            # Unknown file type, don't move
            return 1
            ;;
    esac
}

# Function to process a single file
process_file() {
    local file="$1"
    
    # Skip if should be ignored
    if should_ignore "$file"; then
        return
    fi
    
    # Skip directories for now (could be enhanced later)
    if [[ -d "$file" ]]; then
        # Special case: folders with CANON in name go to Camera
        local basename=$(basename "$file")
        if [[ "$basename" == *"CANON"* ]]; then
            local target_dir="$MEDIA_DIR/Camera"
            move_file "$file" "$target_dir"
        else
            log_info "Skipping directory: $file"
        fi
        return
    fi
    
    # Skip if file doesn't exist (broken symlink, etc.)
    if [[ ! -e "$file" ]]; then
        log_warning "File does not exist: $file"
        return
    fi
    
    # Determine target directory
    local target_dir
    if ! target_dir=$(get_target_directory "$file"); then
        log_info "${DARKBLUE}No rule for file type, leaving in place: $file"
        return
    fi
    
    # Move the file
    move_file "$file" "$target_dir"
}

# Main execution
main() {
    echo -e "${YELLOW}┳┓  ┏┏┓       ┏┓ ┓${NC}"
    echo -e "${ORANGE}┣┫┏┓╋┗┓┏┓┏┓╋  ┏┛ ┃${NC}"
    echo -e "${RED}┛┗┗┻┛┗┛┗┛┛ ┗  ┗━•┻${NC}"
    echo -e "${GREEN}Starting...${NC}"



                  


    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}DRY RUN MODE - No files will be moved${NC}"
    fi
    
    echo ""
    
    # Create base directories
    ensure_dir "$MEDIA_DIR"
    ensure_dir "$ARCHIVE_DIR"
    ensure_dir "$DOCS_DIR"
    ensure_dir "$THREED_DIR"
    
    local total_processed=0
    local total_moved=0
    
    # Process each source directory
    for source_dir in "${SOURCE_DIRS[@]}"; do
        if [[ ! -d "$source_dir" ]]; then
            log_warning "Source directory does not exist: $source_dir"
            continue
        fi
        
        log_info "${PURPLE}Processing directory: $source_dir ${NC}"
        
        # Find all files in the directory (non-recursive for safety)
        while IFS= read -r -d '' file; do
            process_file "$file"
            ((total_processed++))
        done < <(find "$source_dir" -maxdepth 1 -type f -print0 2>/dev/null || true)
        
        # Also check for CANON folders
        while IFS= read -r -d '' dir; do
            local basename=$(basename "$dir")
            if [[ "$basename" == *"CANON"* ]]; then
                process_file "$dir"
                ((total_processed++))
            fi
        done < <(find "$source_dir" -maxdepth 1 -type d -name "*CANON*" -print0 2>/dev/null || true)
    done
    echo ""
    echo -e "${GREEN}Total files processed: $total_processed ${NC}"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}This was a dry run - no files were moved${NC}"
        echo "Run without --dry-run to perform the actual file operations"
    else
        echo -e "${GREEN}Process ended in ${YELLOW}${SECONDS}${GREEN}s with exit code ${YELLOW}0${GREEN}.${NC}"
    fi
}

main "$@"
