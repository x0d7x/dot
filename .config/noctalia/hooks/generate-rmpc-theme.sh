#!/bin/bash
# Generate rmpc theme from noctalia palette
# Reads colors.json and outputs rmpc theme.ron

PALETTE="$HOME/.config/noctalia/colors.json"
OUTPUT="$HOME/.config/rmpc/themes/noctalia.ron"

# Extract colors using jq
primary=$(jq -r '.mPrimary' "$PALETTE")
on_primary=$(jq -r '.mOnPrimary' "$PALETTE")
secondary=$(jq -r '.mSecondary' "$PALETTE")
on_secondary=$(jq -r '.mOnSecondary' "$PALETTE")
tertiary=$(jq -r '.mTertiary' "$PALETTE")
on_tertiary=$(jq -r '.mOnTertiary' "$PALETTE")
surface=$(jq -r '.mSurface' "$PALETTE")
on_surface=$(jq -r '.mOnSurface' "$PALETTE")
surface_variant=$(jq -r '.mSurfaceVariant' "$PALETTE")
on_surface_variant=$(jq -r '.mOnSurfaceVariant' "$PALETTE")
outline=$(jq -r '.mOutline' "$PALETTE")
shadow=$(jq -r '.mShadow' "$PALETTE")
error=$(jq -r '.mError' "$PALETTE")
on_error=$(jq -r '.mOnError' "$PALETTE")
hover=$(jq -r '.mHover' "$PALETTE")
on_hover=$(jq -r '.mOnHover' "$PALETTE")

cat > "$OUTPUT" << THEME
#![enable(implicit_some)]
#![enable(unwrap_newtypes)]
#![enable(unwrap_variant_newtypes)]
(
    default_album_art_path: None,
    draw_borders: false,
    show_song_table_header: false,
    symbols: (song: "🎵", dir: "📁", marker: "\u{e0b0}"),
    layout: Split(
        direction: Vertical,
        panes: [
            (
                size: "9",
                borders: "ALL",
                pane: Split(
                    direction: Horizontal,
                    panes: [
                        (
                            size: "20%",
                            pane: Pane(AlbumArt),
                        ),
                        (
                            size: "70%",
                            pane: Split(
                                direction: Vertical,
                                panes: [
                                    (
                                        size: "2",
                                        pane: Pane(Header),
                                    ),
                                    (
                                        size: "2",
                                        pane: Pane(ProgressBar),
                                    ),
                                ]
                            )
                        ),
                    ]
                ),
            ),
            (
                size: "2",
                pane: Pane(Tabs),
            ),
            (
                size: "70%",
                pane: Pane(TabContent),
            ),
        ],
    ),
    progress_bar: (
        symbols: ["█", "█", " "],
        track_style: (bg: "${outline}"),
        elapsed_style: (fg: "${surface}", bg: "${surface_variant}"),
        thumb_style: (fg: "${primary}", bg: "${surface_variant}"),
    ),
    scrollbar: (
        symbols: ["│", "█", "▲", "▼"],
        track_style: (),
        ends_style: (),
        thumb_style: (fg: "${primary}"),
    ),
    browser_column_widths: [20, 38, 42],
    text_color: "${on_surface}",
    background_color: None,
    header_background_color: None,
    modal_background_color: None,
    modal_backdrop: false,
    tab_bar: (
        enabled: true,
        active_style: (fg: "${surface}", bg: "${primary}", modifiers: "Bold"),
        inactive_style: (fg: "${on_surface_variant}"),
    ),
    borders_style: (fg: "${outline}"),
    highlighted_item_style: (fg: "${on_surface}", modifiers: "Bold"),
    current_item_style: (fg: "${surface}", bg: "${primary}", modifiers: "Bold"),
    highlight_border_style: (fg: "${primary}"),
    song_table_format: [
        (
            prop: (kind: Property(Artist), style: (fg: "${secondary}"),
                highlighted_item_style: (fg: "${surface}", modifiers: "Bold"),
                default: (kind: Text("Unknown"), style: (fg: "${on_surface_variant}"))
            ),
            width: "30%",
            alignment: Right,
        ),
        (
            prop: (kind: Text("-"), style: (fg: "${outline}")),
            width: "1",
            alignment: Center,
        ),
        (
            prop: (kind: Property(Title), style: (fg: "${primary}"),
                highlighted_item_style: (fg: "${surface}", modifiers: "Bold"),
                default: (kind: Text("Unknown"), style: (fg: "${on_surface_variant}"))
            ),
            width: "35%",
        ),
        (
            prop: (kind: Property(Album), style: (fg: "${tertiary}"),
                default: (kind: Text("Unknown Album"), style: (fg: "${on_surface_variant}"))
            ),
            width: "25%",
        ),
    ],
    header: (
        rows: [
            (
                left: [
                    (kind: Text("["), style: (fg: "${primary}", modifiers: "Bold")),
                    (kind: Property(Status(State)), style: (fg: "${primary}", modifiers: "Bold")),
                    (kind: Text("]"), style: (fg: "${primary}", modifiers: "Bold")),
                    (kind: Property(Status(StateV2(playing_label: " ", paused_label: "❚❚", stopped_label: "❚❚"))), style: (fg: "${primary}", modifiers: "Bold")),
                ],
                center: [
                    (kind: Property(Song(Artist)), style: (fg: "${on_surface}", modifiers: "Bold"),
                        default: (kind: Text("Unknown"), style: (fg: "${on_surface_variant}", modifiers: "Bold"))
                    ),
                    (kind: Text(" - ")),
                    (kind: Property(Song(Title)), style: (fg: "${primary}", modifiers: "Bold"),
                        default: (kind: Text("No Song"), style: (fg: "${primary}", modifiers: "Bold"))
                    ),
                    (kind: Text(" - ")),
                    (kind: Property(Status(Elapsed)), style: (fg: "${primary}", modifiers: "Bold"))
                ],
                right: [
                    (kind: Text("Vol: "), style: (fg: "${secondary}", modifiers: "Bold")),
                    (kind: Property(Status(Volume)), style: (fg: "${secondary}", modifiers: "Bold")),
                    (kind: Text("% "), style: (fg: "${secondary}", modifiers: "Bold")),
                ]
            )
        ],
    ),
    browser_song_format: [
        (
            kind: Group([
                (kind: Property(Track)),
                (kind: Text(" ")),
            ])
        ),
        (
            kind: Group([
                (kind: Property(Artist)),
                (kind: Text(" - ")),
                (kind: Property(Title)),
            ]),
            default: (kind: Property(Filename))
        ),
    ],
)
THEME

echo "rmpc theme generated: $OUTPUT"
