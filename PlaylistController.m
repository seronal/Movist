//
//  Movist
//
//  Created by dckim <cocoable@gmail.com>
//  Copyright 2006 cocoable. All rights reserved.
//

#import "PlaylistController.h"

#import "PlaylistCell.h"
#import "Playlist.h"
#import "MMovie.h"
#import "MSubtitle.h"
#import "AppController.h"

#define MPlayingColumnIdentifier   @"playing"
#define MMovieColumnIdentifier     @"movie"

@implementation PlaylistController

- (id)initWithAppController:(AppController*)appController
                   playlist:(Playlist*)playlist
{
    //TRACE(@"%s %@", __PRETTY_FUNCTION__, playlist);
    if (self = [super initWithWindowNibName:@"Playlist"]) {
        [self setWindowFrameAutosaveName:@"PlaylistWindow"];
        _appController = [appController retain];
        _playlist = [playlist retain];
    }
    return self;
}

- (void)windowDidLoad
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    NSTableColumn* column;
    column = [_tableView tableColumnWithIdentifier:MPlayingColumnIdentifier];
    [column setDataCell:[[[NSCell alloc] initImageCell:nil] autorelease]];

    column = [_tableView tableColumnWithIdentifier:MMovieColumnIdentifier];
    [column setDataCell:[[[PlaylistMovieCell alloc] init] autorelease]];

    [_tableView setDoubleAction:@selector(playlistItemDoubleClicked:)];
    [_tableView registerForDraggedTypes:MOVIST_DRAG_TYPES];

    [self updateUI];
}

- (void)dealloc
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    [_playlist release];
    [_appController release];
    [super dealloc];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -

- (void)runSheetForWindow:(NSWindow*)window
{
    //TRACE(@"%s %@", __PRETTY_FUNCTION__, window);
    [self updateUI];

    [NSApp beginSheet:[self window] modalForWindow:window modalDelegate:self
       didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (void)didEndSheet:(NSWindow*)sheet
         returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
    //TRACE(@"%s %@ (ret=%d)", __PRETTY_FUNCTION__, sheet, returnCode);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -

- (void)playlistItemDoubleClicked:(id)sender
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    int row = [_tableView clickedRow];
    if (0 <= row && row < [_playlist count]) {
        [_playlist setCurrentItemAtIndex:row];
        if ([_appController openCurrentPlaylistItem]) {
            [_tableView reloadData];    // update current play
            [self closeAction:self];
        }
    }
}

- (void)keyDown:(NSEvent*)event
{
    TRACE(@"%s \'0x%x\'", __PRETTY_FUNCTION__,
          [[event characters] characterAtIndex:0]);
    if (![event isARepeat]) {
        unichar key = [[event characters] characterAtIndex:0];
        if (key == NSDeleteCharacter ||     // backward delete
            key == NSDeleteFunctionKey) {   // forward delete
            [self removeAction:self];
        }
    }
}

- (IBAction)addAction:(id)sender
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:TRUE];
    if (NSOKButton == [panel runModalForTypes:nil]) {
        int row = MAX(0, [[_tableView selectedRowIndexes] firstIndex]);
        [_playlist insertFile:[panel filename] atIndex:row addSeries:FALSE];
        [self updateUI];

        [_tableView selectRow:row byExtendingSelection:FALSE];
    }
}

- (IBAction)removeAction:(id)sender
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    NSIndexSet* indexes = [_tableView selectedRowIndexes];
    if (0 < [indexes count]) {
        int firstRow = [indexes firstIndex];
        [_playlist removeItemsAtIndexes:indexes];
        [self updateUI];

        firstRow = MIN(firstRow, [_playlist count] - 1);
        [_tableView selectRow:firstRow byExtendingSelection:FALSE];
    }
}

- (IBAction)modeAction:(id)sender
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    [_playlist setRepeatMode:([_playlist repeatMode] + 1) % MAX_REPEAT_MODE];
    [self updateRepeatUI];
    [_appController updateRepeatUI];
}

- (IBAction)closeAction:(id)sender
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    [[self window] orderOut:self];
    [NSApp endSheet:[self window]];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -

- (void)updateRemoveButton
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    BOOL itemSelected = (0 <= [_tableView selectedRow]);
    if (itemSelected) {
        [_removeButton setImage:[NSImage imageNamed:@"PlaylistRemove"]];
        [_removeButton setAlternateImage:[NSImage imageNamed:@"PlaylistRemovePressed"]];
    }
    else {
        NSImage* image = [NSImage imageNamed:@"PlaylistRemoveDisabled"];
        [_removeButton setImage:image];
        [_removeButton setAlternateImage:image];
    }
}

- (void)updateRepeatUI
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    [_modeButton setImage:[NSImage imageNamed:
        ([_playlist repeatMode] == REPEAT_OFF) ? @"RepeatOff" :
        ([_playlist repeatMode] == REPEAT_ONE) ? @"RepeatOne" :
                                                 @"RepeatAll"]];
}

- (void)updateUI
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    [_tableView reloadData];
    [self updateRemoveButton];
    [self updateRepeatUI];

    [_statusTextField setStringValue:[NSString stringWithFormat:
        NSLocalizedString(@"%d items", nil), [_playlist count]]];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark data-source

- (int)numberOfRowsInTableView:(NSTableView*)tableView
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    return [_playlist count];
}

- (id)tableView:(NSTableView*)tableView
    objectValueForTableColumn:(NSTableColumn*)tableColumn
            row:(int)rowIndex
{
    //TRACE(@"%s %@ %d", __PRETTY_FUNCTION__, [tableColumn identifier], rowIndex);
    NSString* identifier = [tableColumn identifier];
    PlaylistItem* item = [_playlist itemAtIndex:rowIndex];
    if ([identifier isEqualToString:MPlayingColumnIdentifier]) {
        NSCell* cell = [tableColumn dataCellForRow:rowIndex];
        if (![item isEqualTo:[_playlist currentItem]]) {
            [cell setImage:nil];
        }
        else if (![_appController movie] ||
                 [[_appController movie] rate] == 0.0) {
            [cell setImage:[NSImage imageNamed:@"PlaylistCurrent"]];
        }
        else {
            [cell setImage:[NSImage imageNamed:@"PlaylistPlaying"]];
        }
        return nil;
    }
    else if ([identifier isEqualToString:MMovieColumnIdentifier]) {
        return item;
    }
    return nil;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark drag-and-drop

- (void)replaceSubtitle:(NSURL*)subtitleURL atIndex:(int)index
{
    //TRACE(@"%s %@ at %d", __PRETTY_FUNCTION__, [subtitleURL absoluteString], index);
    PlaylistItem* item = [_playlist itemAtIndex:index];
    [item setSubtitleURL:subtitleURL];

    if ([item isEqualTo:[_playlist currentItem]]) {
        [_appController reopenSubtitle];
    }
}

- (BOOL)tableView:(NSTableView*)tv writeRowsWithIndexes:(NSIndexSet*)rowIndexes
     toPasteboard:(NSPasteboard*)pboard
{
    //TRACE(@"%s %@", __PRETTY_FUNCTION__, rowIndexes);
    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObject:MPlaylistItemDataType] owner:self];
    [pboard setData:data forType:MPlaylistItemDataType];
    return TRUE;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
    //TRACE(@"%s row=%d, op=%d", __PRETTY_FUNCTION__, row, op);
    NSPasteboard* pboard = [info draggingPasteboard];
    unsigned int dragAction = dragActionFromPasteboard(pboard, FALSE);
    switch (dragAction) {
        case DRAG_ACTION_ADD_FILES :
        case DRAG_ACTION_ADD_URL :
            if (op == NSTableViewDropAbove) {
                return NSDragOperationCopy;
            }
            break;
        case DRAG_ACTION_REPLACE_SUBTITLE_FILE :
        case DRAG_ACTION_REPLACE_SUBTITLE_URL :
            if (op == NSTableViewDropOn) {
                return NSDragOperationCopy;
            }
            break;
        case DRAG_ACTION_REORDER_PLAYLIST :
            if (op == NSTableViewDropAbove) {
                return NSDragOperationMove;
            }
            break;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id<NSDraggingInfo>)info
              row:(int)row dropOperation:(NSTableViewDropOperation)op
{
    //TRACE(@"%s row=%d, op=%d", __PRETTY_FUNCTION__, row, op);
    NSPasteboard* pboard = [info draggingPasteboard];
    unsigned int dragAction = dragActionFromPasteboard(pboard, FALSE);
    switch (dragAction) {
        case DRAG_ACTION_ADD_FILES : {
            NSArray* filenames = [pboard propertyListForType:NSFilenamesPboardType];
            [_playlist insertFiles:filenames atIndex:row];
            [self updateUI];
            return TRUE;
        }
        case DRAG_ACTION_ADD_URL : {
            NSURL* url = [NSURL URLFromPasteboard:pboard];
            [_playlist insertURL:url atIndex:row];
            [self updateUI];
            return TRUE;
        }
        case DRAG_ACTION_REPLACE_SUBTITLE_FILE : {
            NSArray* filenames = [pboard propertyListForType:NSFilenamesPboardType];
            NSURL* subtitleURL = [NSURL fileURLWithPath:[filenames objectAtIndex:0]];
            [self replaceSubtitle:subtitleURL atIndex:row];
            [_tableView reloadData];
            return TRUE;
        }
        case DRAG_ACTION_REPLACE_SUBTITLE_URL : {
            NSURL* subtitleURL = [NSURL URLFromPasteboard:pboard];
            [self replaceSubtitle:subtitleURL atIndex:row];
            [_tableView reloadData];
            return TRUE;
        }
        case DRAG_ACTION_REORDER_PLAYLIST : {
            NSData* data = [pboard dataForType:MPlaylistItemDataType];
            NSIndexSet* indexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            int newFirstRow = [_playlist moveItemsAtIndexes:indexes toIndex:row];
            [_tableView reloadData];

            // re-select original selections
            NSRange range = NSMakeRange(newFirstRow, [indexes count]);
            [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndexesInRange:range]
                    byExtendingSelection:FALSE];
            return TRUE;
        }
    }
    return FALSE;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark delegate

- (void)tableViewSelectionDidChange:(NSTableView*)tableView
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    [self updateRemoveButton];
}

@end