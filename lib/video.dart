import 'dart:io';
import 'package:process_run/process_run.dart';

Future<ProcessResult> ffmpeg(String args) async {
  final shell = Shell(verbose: false);
  return (await shell.run('ffmpeg $args'))[0];
}

Future<ProcessResult> ffprobe(String args) async {
  final shell = Shell(verbose: false);
  return (await shell.run('ffprobe $args'))[0];
}

void main() async {}

Future<double> videoDuration(String path) async {
  return double.parse((await ffprobe(
          '-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $path'))
      .stdout
      .toString());
}

Future<ProcessResult> mergeVideos(
    List<String> inputFilepaths, String outputFilepath) async {
  final concatName = 'concat.txt';
  final concatFile = File(concatName);
  await concatFile.writeAsString('file ${inputFilepaths.join('\nfile ')}\n');
  final result = await ffmpeg('-f concat -i $concatName -c copy output.ts');
  await concatFile.delete();
  return result;
}
