﻿package 
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.ui.Mouse;
	import flash.utils.ByteArray;
	import cmodule.quake.CLibInit;
	import flash.utils.getTimer;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.geom.Rectangle;
	import flash.net.SharedObject;
	import flash.display.StageScaleMode;
	import flash.events.SampleDataEvent;
	import flash.media.SoundChannel;
	import flash.media.Sound;
	
	/**
	 * ...
	 * @author Michael Rennie
	 */
	public class Quake extends Sprite 
	{
		private var _loader:CLibInit;
		private var _swc:Object;
		private var _swcRam:ByteArray;
		
		private var _bitmapData:BitmapData;//This is null until after we have called the first _swc.swcFrame()
		private var _bitmap:Bitmap;
		private var _rect:Rectangle;
	
		private var _sound:Sound;
		private var _soundChannel:SoundChannel;
		private var _lastSampleDataPosition:int;//Reset to 0 everytime a restart the sound.
		
		private var _oldmouseX:int, _oldmouseY:int;
		private var _buttonDown:Boolean = false;
				
		[Embed(source="../embed/id1/PAK0.PAK", mimeType="application/octet-stream")]
		private var EmbeddedPak0:Class;
		[Embed(source="../embed/id1/PAK1.PAK", mimeType="application/octet-stream")]
		private var EmbeddedPak1:Class;
		[Embed(source="../embed/id1/config.cfg", mimeType="application/octet-stream")]
		private var EmbeddedDefaultConfig:Class;
		[Embed(source="../embed/id1/autoexec.cfg", mimeType="application/octet-stream")]
		private var EmbeddedDefaultAutoexec:Class;
		
		public function Quake():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
				
		private function init(e:Event = null):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			// entry point

			_sound = new Sound();
			_sound.addEventListener( SampleDataEvent.SAMPLE_DATA, sampleDataHandler );
			//_soundBuffer = new ByteArray;
			
			//init swc
			_loader = new CLibInit;
			_swc = _loader.init();
			
			//If we havent already got a config.cfg saved in the SharedObjects, then we load the embedded one.
			//This will override some default controls from default.cfg inside the pak file, which 99% of users will change. 
			//(WASD keys, as well as Always Run).
			fileSupplyDefaultEmbedded("./id1/config.cfg", EmbeddedDefaultConfig);
			fileSupplyDefaultEmbedded("./id1/autoexec.cfg", EmbeddedDefaultAutoexec);
			
			var pakFile0:ByteArray = new EmbeddedPak0;
			_loader.supplyFile("./id1/pak0.pak", pakFile0);
			var pakFile1:ByteArray = new EmbeddedPak1;
			_loader.supplyFile("./id1/pak1.pak", pakFile1);
			_swcRam = _swc.swcInit(this);
			
			_swc.swcInitQuake(null);

			stage.addEventListener(Event.ENTER_FRAME, onFrame);
			stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		}
		
		private function onFrame(e:Event):void
		{
			//Check for mouse movement. It is much more accurate to do this every frame than in a MOUSE_MOVE event.
			if(_buttonDown)
			{
				var deltaX:int = mouseX - _oldmouseX;
				var deltaY:int = mouseY - _oldmouseY;
				
				const MOUSE_MULTIPLIER:Number = 8;
				_swc.swcDeltaMouse(deltaX * MOUSE_MULTIPLIER, deltaY * MOUSE_MULTIPLIER);
			}
			_oldmouseX = mouseX;
			_oldmouseY = mouseY;
			
			//Run the game frame, and get the pointer to its frame buffer
			var newTime:Number = getTimer() / 1000;
			var ptr:uint = _swc.swcFrame(newTime);
										
			if (!_bitmapData)
			{
				//Wait for the first frame before adding the bitmap.
				var width:uint = 640;
				var height:uint = 480;
				_bitmapData = new BitmapData(width, height, false);
				_rect = new Rectangle(0, 0, width, height);
				_bitmap = new Bitmap(_bitmapData);
				addChild(_bitmap);
			}
			_swcRam.position = ptr;
			_bitmapData.setPixels(_rect, _swcRam);
					
			if (!_soundChannel)
			{
				_lastSampleDataPosition = 0;
				_soundChannel = _sound.play();
				_soundChannel.addEventListener(Event.SOUND_COMPLETE, soundCompleteHandler);
			}
		}
		
		private function soundCompleteHandler(e:Event):void
		{
			//The sound stopped playing because it ran out of samples, so make it restart next frame.
			_soundChannel.removeEventListener(Event.SOUND_COMPLETE, soundCompleteHandler);
			_soundChannel = null;
		}
		
		private function sampleDataHandler(event:SampleDataEvent):void
		{
			//The sound channel is requesting more samples. If it ever runs out then a sound complete message will occur.
					
			//Ask the game to paint its channels to our sample ByteArray.
			//Also need to supply a deltaT to update the game's internal sound time.
			var soundDeltaT:int = event.position - _lastSampleDataPosition;
			_swc.swcWriteSoundData(event.data, soundDeltaT);
			_lastSampleDataPosition = event.position;
		}
		
		private function onKeyDown( e:KeyboardEvent ):void
		{
			//trace("onKeyDown: ", e.keyCode);
			_swc.swcKey(e.keyCode, 1);
		}
		private function onKeyUp( e:KeyboardEvent ):void
		{
			_swc.swcKey(e.keyCode, 0);
		}
		private function onMouseDown(e:MouseEvent):void 
		{
			_oldmouseX = mouseX;
			_oldmouseY = mouseY;
			_buttonDown = true;
			Mouse.hide();
		}
		private function onMouseUp(e:MouseEvent):void 
		{
			_buttonDown = false;
			Mouse.show();
		}

		//We keep a record of the ByteArray for each file, because CLibInit.supplyFile
		//only allows a file to be supplied with a ByteArray ONCE only.
		private var _fileByteArrays:Array = new Array;
		
		public function fileSupplyDefaultEmbedded(filename:String, defaultEmbed:Class):void
		{
			if (!fileReadSharedObject(filename))//Check if its in the SharedObjects first
			{
				//Havent yet got the file saved in the SharedObjects, so we load the embedded data as its default value.
				
				var file:ByteArray = new defaultEmbed;
				_fileByteArrays[filename] = file;	//So that we can still overwrite it
				_loader.supplyFile(filename, file);//So that it can be read later on
			}
		}
		public function fileReadSharedObject(filename:String):Boolean
		{
			var sharedObject:SharedObject = SharedObject.getLocal(filename);
			if (!sharedObject)
				return false;	//Shared objects not enabled
			
			if (!sharedObject.data.byteArray)
				return false;	//Havent yet saved a shared object for this file
				
			if (!_fileByteArrays[filename])
			{
				//This is the first time we are accessing this file, so record and supply the ByteArray for it
				//from the SharedObject
				var byteArray:ByteArray = sharedObject.data.byteArray;
				_fileByteArrays[filename] = byteArray;
				_loader.supplyFile(filename, byteArray);
			}
			
			return true;//We did find its SharedObject, so return true
		}
		public function fileWriteSharedObject(filename:String):ByteArray
		{
			var sharedObject:SharedObject = SharedObject.getLocal(filename);
			if (!sharedObject)
				return undefined;	//Shared objects not enabled
			
			var byteArray:ByteArray;
			if (!_fileByteArrays[filename])
			{
				//Havent yet created a ByteArray for this file, so create a blank one.
				byteArray = new ByteArray;
				_fileByteArrays[filename] = byteArray;
				
				//Supply the ByteArray as a file, so that it can also be read later on, if needed.
				_loader.supplyFile(filename, byteArray);
			}
			else
			{
				byteArray = _fileByteArrays[filename];
				
				//We are opening the file for writing, so reset its length to 0.
				//Needed because this is NOT done by funopen(byteArray, ...)
				byteArray.length = 0;
			}
			
			//Return the ByteArray, allowing it to be opened as a FILE* for writing using funopen(byteArray, ...)
			return byteArray;
		}
		
		//SharedObjects are used to save quake config files	
		public function fileUpdateSharedObject(filename:String):void
		{
			var sharedObject:SharedObject = SharedObject.getLocal(filename);
			
			if (!sharedObject)
				return;			//Shared objects not enabled
				
			if (!_fileByteArrays[filename])
			{
				//This can happen if fileUpdateSharedObject is called before fileWriteSharedObject or fileReadSharedObject
				trace("Error: fileUpdateSharedObject() called on a file without a ByteArray");
			}
			
			sharedObject.data.byteArray = _fileByteArrays[filename];
			sharedObject.flush();
		}
	}
}