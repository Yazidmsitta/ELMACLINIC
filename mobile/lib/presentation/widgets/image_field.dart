import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
class DraftImage { const DraftImage(this.bytes,this.mime); final Uint8List bytes; final String mime; }
class ImageField extends StatefulWidget {
 const ImageField({super.key,required this.onChanged,this.enabled=true,this.existingUrl});
 final ValueChanged<DraftImage?> onChanged; final bool enabled; final String? existingUrl;
 @override State<ImageField> createState()=>_ImageFieldState();
}
class _ImageFieldState extends State<ImageField>{
 DraftImage? _image;bool _busy=false;String? _error;
 Future<void> _choose()async{
 setState((){_busy=true;_error=null;});try{
 final picker=ImagePicker();final lost=await picker.retrieveLostData();
 final f=lost.files?.firstOrNull??await picker.pickImage(source:ImageSource.gallery,maxWidth:1600,maxHeight:1600,imageQuality:85);
 if(f==null)return;if(await f.length()>2*1024*1024){if(mounted)setState(()=>_error='Image limitée à 2 Mo.');return;}
 final bytes=await f.readAsBytes();final mime=bytes.length>=3&&bytes[0]==255&&bytes[1]==216?'image/jpeg':bytes.length>=8&&bytes[0]==137&&bytes[1]==80?'image/png':'image/webp';
 if(mounted){setState(()=>_image=DraftImage(bytes,mime));widget.onChanged(_image);}
 }catch(_){if(mounted)setState(()=>_error='Impossible de lire cette photo. Réessayez.');}finally{if(mounted)setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Text('Photo (facultative)',style:TextStyle(fontWeight:FontWeight.w600)),
 if(_image!=null)Image.memory(_image!.bytes,height:140,fit:BoxFit.cover)else if(widget.existingUrl!=null)Image.network(widget.existingUrl!,height:140,errorBuilder:(_,error,stack)=>const Text('Photo indisponible')),
 TextButton(onPressed:widget.enabled&&!_busy?_choose:null,child:Text(_busy?'Chargement…':'Choisir une photo')),
 if(_image!=null)TextButton(onPressed:widget.enabled&&!_busy?(){setState(()=>_image=null);widget.onChanged(null);}:null,child:const Text('Retirer la sélection')),
 if(_error!=null)Text(_error!),
 ]);
}
