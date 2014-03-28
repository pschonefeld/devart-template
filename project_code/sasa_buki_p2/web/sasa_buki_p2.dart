import 'dart:html';
import 'dart:web_audio'; 
import 'dart:typed_data';
import 'dart:async';

bool _record = false;
int _time = 0;
var _currentVol;
var _xOffset = 300;
int _y = 0;
List<int> _volumeSeries = [];

void main() {
  
  //setup
  AudioContext context = new AudioContext();  
  ScriptProcessorNode  processor = context.createScriptProcessor(2048, 1, 1);
  AnalyserNode analyser = context.createAnalyser();
  analyser.smoothingTimeConstant = 0.3;
  analyser.fftSize = 1024;   
  MediaStreamAudioDestinationNode destination = context.createMediaStreamDestination();
  
  //connect nodes and input
  window.navigator.getUserMedia(audio:true).then((MediaStream stream) {
      MediaStreamAudioSourceNode mediaStreamSource = context.createMediaStreamSource(stream);
      mediaStreamSource.connectNode(analyser);
      analyser.connectNode(processor);
      processor.connectNode(destination);
  });

  //do stuff here
  processor.onAudioProcess.listen((_){
    Uint8List list = new Uint8List(analyser.frequencyBinCount);
    analyser.getByteFrequencyData(list);
    double average = list.fold(0, (prev,elem)=>prev+elem)/list.length;
    if(average>20){
      String d = querySelector("#svgPath").attributes["d"];
      var x1 = _xOffset - average.truncate();
      var x2 = _xOffset + average.truncate();      
      querySelector("#svgPath").attributes["d"] = "$d L$x1,${_y++} L$x2,${_y++} "; 
    }
    else{
      querySelector("#svgPath").attributes["d"] = "M${_xOffset},0";
      _y = 0;
    }
  });   
  
}

void cb(Timer t){
  
  int yOffset = ++_time;  
  _volumeSeries.add(_xOffset - _currentVol.truncate());
  List<String> sPath = [];
  int start = 0;
  _volumeSeries.forEach((i){
    sPath.add("l$i,${++start}");
  });
  


}

