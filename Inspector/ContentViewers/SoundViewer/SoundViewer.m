/* SoundViewer.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <AppKit/AppKit.h>
#include "SoundViewer.h"
#include "GNUstep.h"

@implementation SoundViewer

- (void)dealloc
{
	TEST_RELEASE (bundlePath);
  TEST_RELEASE (dataRep);
	TEST_RELEASE (soundPath);
	TEST_RELEASE (sound);
  RELEASE (playBox);  
  RELEASE (errLabel);
	RELEASE (indicator);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
          inspector:(id)insp
{
	self = [super initWithFrame: frameRect];

	if(self) {
		NSBundle *bundle;
		NSString *imagePath;
		NSImage *image;
		
		playBox = [[NSBox alloc] initWithFrame: NSMakeRect(30, 125, 197, 80)];	
    [playBox setBorderType: NSGrooveBorder];
		[playBox setTitle: NSLocalizedString(@"Player", @"")];
    [playBox setTitlePosition: NSAtTop];
		[playBox setContentViewMargins: NSMakeSize(0, 0)]; 
		[self addSubview: playBox]; 

		bundle = [NSBundle bundleForClass: [self class]];
		
		stopButt = [[NSButton alloc] initWithFrame: NSMakeRect(56, 30, 24, 24)];
		[stopButt setButtonType: NSMomentaryLight];
		[stopButt setImagePosition: NSImageOnly];
		imagePath = [bundle pathForResource: @"stop" ofType: @"tiff" inDirectory: nil];		
		image = [[NSImage alloc] initWithContentsOfFile: imagePath];
		[stopButt setImage: image];
		RELEASE (image);
		[stopButt setTarget:self];
		[stopButt setAction:@selector(buttonsAction:)];
		[playBox addSubview: stopButt]; 
    RELEASE (pauseButt);
    
		pauseButt = [[NSButton alloc] initWithFrame: NSMakeRect(86, 30, 24, 24)];
		[pauseButt setButtonType: NSMomentaryLight];
		[pauseButt setImagePosition: NSImageOnly];
		imagePath = [bundle pathForResource: @"pause" ofType: @"tiff" inDirectory: nil];		
		image = [[NSImage alloc] initWithContentsOfFile: imagePath];
		[pauseButt setImage: image];
		RELEASE (image);
		[pauseButt setTarget:self];
		[pauseButt setAction:@selector(buttonsAction:)];
		[playBox addSubview: pauseButt]; 
    RELEASE (pauseButt);

		playButt = [[NSButton alloc] initWithFrame: NSMakeRect(116, 30, 24, 24)];
		[playButt setButtonType: NSMomentaryLight];
		[playButt setImagePosition: NSImageOnly];
		imagePath = [bundle pathForResource: @"play" ofType: @"tiff" inDirectory: nil];		
		image = [[NSImage alloc] initWithContentsOfFile: imagePath];
		[playButt setImage: image];
		RELEASE (image);
		[playButt setTarget:self];
		[playButt setAction:@selector(buttonsAction:)];
		[playBox addSubview: playButt]; 
    RELEASE (playButt);
		
		indicator = [[NSProgressIndicator alloc] 
												initWithFrame: NSMakeRect(10, 6, 172, 16)];
		[indicator setIndeterminate: YES];
		[playBox addSubview: indicator]; 
								
    editButt = [[NSButton alloc] initWithFrame: NSMakeRect(141, 10, 115, 25)];
	  [editButt setButtonType: NSMomentaryLight];
    [editButt setImage: [NSImage imageNamed: @"common_ret.tiff"]];
    [editButt setImagePosition: NSImageRight];
	  [editButt setTitle: NSLocalizedString(@"Edit", @"")];
	  [editButt setTarget: self];
	  [editButt setAction: @selector(editFile:)];	
    [editButt setEnabled: NO];		
		[self addSubview: editButt]; 
    RELEASE (editButt);
    
  	errLabel = [[NSTextField alloc] init];	
		[errLabel setFrame: NSMakeRect(5, 162, [self frame].size.width - 10, 25)];
  	[errLabel setAlignment: NSCenterTextAlignment];
		[errLabel setFont: [NSFont systemFontOfSize: 18]];
  	[errLabel setBackgroundColor: [NSColor windowBackgroundColor]];
  	[errLabel setTextColor: [NSColor darkGrayColor]];	
  	[errLabel setBezeled: NO];
  	[errLabel setEditable: NO];
  	[errLabel setSelectable: NO];
		[errLabel setStringValue: NSLocalizedString(@"Invalid Contents", @"")];
    
    bundlePath = nil;
    dataRep = nil;
    soundPath = nil;
		sound = nil;
                
    inspector = insp;
    ws = [NSWorkspace sharedWorkspace];
    
    valid = YES;
	}
	
	return self;
}

- (void)setBundlePath:(NSString *)path
{
  ASSIGN (bundlePath, path);
}

- (NSString *)bundlePath
{
  return bundlePath;
}

- (void)setDataRepresentation:(NSData *)rep
{
  ASSIGN (dataRep, rep);
}

- (NSData *)dataRepresentation
{
  return dataRep;
}

- (void)setIsRemovable:(BOOL)value
{
  removable = value;
}

- (BOOL)isRemovable
{
  return removable;
}

- (void)setIsExternal:(BOOL)value
{
  external = value;
}

- (BOOL)isExternal
{
  return external;
}

- (void)buttonsAction:(id)sender
{
	if (sender == playButt) {
		if (sound) {
      if ([sound resume] == NO) {
        if ([sound isPlaying] == NO) {
		      [indicator startAnimation: self];
		      [sound play];
        }
      }
		}
		
	} else if (sender == pauseButt) {
		if (sound && [sound isPlaying]) {
			[indicator stopAnimation: self];
			[sound pause];
		}
		
	} else if (sender == stopButt) {
		if (sound && [sound isPlaying]) {
			[indicator stopAnimation: self];
			[sound stop];
      [editButt setEnabled: YES];	
      [[self window] makeFirstResponder: editButt];
		}
	}
}

- (void)editFile:(id)sender
{
	NSString *appName, *type;

  [ws getInfoForFile: soundPath application: &appName type: &type];

	if (appName != nil) {
		[ws openFile: soundPath withApplication: appName];
	}
}

- (void)displayPath:(NSString *)path
{
  NSSound *snd;
  
	if (sound) {
		if ([sound isPlaying]) {
			[sound stop];
			[indicator stopAnimation: self];
		}
		DESTROY (sound);
	}
  
	ASSIGN (soundPath, path);

  if ([self superview]) {      
    [inspector contentsReadyAt: soundPath];
  }
  
  snd = [[NSSound alloc] initWithContentsOfFile: soundPath 
                                    byReference: NO]; 
  
  if (snd) {
    ASSIGN (sound, snd);
  
		if (valid == NO) {
			[errLabel removeFromSuperview]; 
      [self addSubview: playBox];   
			valid = YES;
		}		  
    
    [editButt setEnabled: YES];	
    [[self window] makeFirstResponder: editButt];
    	
  } else {
    if (valid == YES) {
      DESTROY (sound);
			[playBox removeFromSuperview]; 
      [self addSubview: errLabel]; 
      [editButt setEnabled: NO];		      
			valid = NO;
    }
  }
  
  DESTROY (snd);
}

- (void)displayLastPath:(BOOL)forced
{
  if (soundPath) {
    if (forced) {
      [self displayPath: soundPath];
    } else {
      [inspector contentsReadyAt: soundPath];
    }
  }
}

- (void)displayData:(NSData *)data 
             ofType:(NSString *)type
{
}

- (NSString *)currentPath
{
  return soundPath;
}

- (void)stopTasks
{
	if (sound) {
		if ([sound isPlaying]) {
			[sound stop];
			[indicator stopAnimation: self];
		}
		DESTROY (sound);
	}
}

- (BOOL)canDisplayPath:(NSString *)path
{
  NSDictionary *attributes;
	NSString *defApp, *fileType, *extension;
	NSArray *types;

  attributes = [[NSFileManager defaultManager] fileAttributesAtPath: path
                                                       traverseLink: YES];
  if ([attributes objectForKey: NSFileType] == NSFileTypeDirectory) {
    return NO;
  }		
			
	[ws getInfoForFile: path application: &defApp type: &fileType];
	
  if(([fileType isEqual: NSPlainFileType] == NO)
                  && ([fileType isEqual: NSShellCommandFileType] == NO)) {
    return NO;
  }

	extension = [path pathExtension];
	types = [NSArray arrayWithObjects: @"aiff", @"wav", @"snd", @"au", nil];

	if ([types containsObject: [extension lowercaseString]]) {
		return YES;
	}
//	if ([[NSSound soundUnfilteredFileTypes] containsObject: extension]) {
//		return YES;
//	}

	return NO;
}

- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return NO;
}

- (NSString *)winname
{
	return NSLocalizedString(@"Sound Inspector", @"");	
}

- (NSString *)description
{
	return NSLocalizedString(@"This Inspector allow you to play a sound file", @"");	
}

@end