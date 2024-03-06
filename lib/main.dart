import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:avif/lista_produtos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MaterialApp(
    home: BaixarImage(),
  ));
}

class BaixarImage extends StatefulWidget {
  const BaixarImage({Key? key}) : super(key: key);

  @override
  State<BaixarImage> createState() => _BaixarImageState();
}

class _BaixarImageState extends State<BaixarImage> {
List<File> _originalImages = [];
  List<Map<String, dynamic>> listaProduto = [];
  Set<int> marcasSelecionadas = {};
  Map<int, int> imagensPorMarca = {};
  Map<int, int> totalImagensPorMarca = {};
  Map<int, int> imagensBaixadasPorMarca = {};
  late Directory diretorio;
  String caminhoArquivo = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      receberProdutos();
    });
  }

  Future<void> receberProdutos() async {
    log('aqui');

    try {
      diretorio = (await getExternalStorageDirectory())!;

      listaProduto = listaProdutoDB; 

      log('listaProduto');

      final diretorioProduto = Directory('${diretorio.path}/produto');
      final imagensBaixadas = await diretorioProduto.list().toList();

      // if (!(await diretorioProduto.exists())) {
      // }

      for (final produto in listaProduto) {
        final marcaCode = int.parse(produto['cd_marca'].toString());
        marcasSelecionadas.add(marcaCode);
        imagensPorMarca[marcaCode] = 0;

        if (produto['lista_produto_imagem'] != null) {
          final listaImage = jsonDecode(produto['lista_produto_imagem']) as List;
          totalImagensPorMarca[marcaCode] = listaImage.length;
        }

        // log('marcaCode:$marcaCode');

        contarImagensBaixadas(imagensBaixadas, marcaCode);
      }
    } catch (e) {
      log('Erro: $e');
    }

    // final res = await receberListaProduto(appData.usuario);
    // if (res.isNotEmpty) {
    //   try {
    //     final dados = await res['dados'];
    //     listaProduto = List<Map<String, dynamic>>.from(dados['lista_produto']);

    //     for (final produto in listaProdutos) {
    //       final marcaCode = int.parse(produto['cd_marca'].toString());
    //       marcasSelecionadas.add(marcaCode);
    //       imagensPorMarca[marcaCode] = 0;

    //       final listaImage = jsonDecode(produto['lista_produto_imagem']) as List;
    //       totalImagensPorMarca[marcaCode] = listaImage.length;

    //       log('marcaCode:$marcaCode');

    //       await contarImagensBaixadas(marcaCode);
    //     }
    //   } catch (e) {
    //     log('Erro: $e');
    //   }
    // }

    setState(() {});
  }

  void contarImagensBaixadas(List<FileSystemEntity> imagensBaixadas, int marcaCode) {
    try {
      int contador = 0;
      for (var imagem in imagensBaixadas) {
        final nomeArquivo = imagem.path.split('/').last;
        final partesNome = nomeArquivo.split('_');
        if (partesNome.length == 2) {
          final codigoMarca = int.tryParse(partesNome[0]);
          if (codigoMarca == marcaCode) {
            contador++;
          }
        }
      }

      imagensBaixadasPorMarca[marcaCode] = contador;
    } catch (e) {
      log('Erro ao contar imagens baixadas para a marca $marcaCode: $e');
    }
  }

Future<void> pegarUrl({List<Map<String, dynamic>>? produtos}) async {
  imagensBaixadasPorMarca.clear();

  final listaProdutosParaBaixar = produtos ?? listaProduto;

  for (final produto in listaProdutosParaBaixar) {
    final marcaCode = int.parse(produto['cd_marca'].toString());

    if (marcasSelecionadas.isEmpty || marcasSelecionadas.contains(marcaCode)) {
      final cdProduto = produto['cd_produto'];
      final listaImage = jsonDecode(produto['lista_produto_imagem']) as List;
      
      for (var i = 0; i < listaImage.length; i++) {
        final urlImagem = listaImage[i] as String;
        await baixarImagem(urlImagem, cdProduto, marcaCode);

        imagensPorMarca[marcaCode] = i + 1;

        setState(() {});
      }
    }
  }
}


 Future<void> baixarImagem(String urlImagem, cdProduto, int marcaCode) async {
  try {
    final response = await http.get(Uri.parse(urlImagem));
    final bytes = response.bodyBytes;

    final Uint8List avifBytes = await encodeAvif(bytes);

    final pastaDestino = '${diretorio.path}/produto';

    await Directory(pastaDestino).create(recursive: true);

    final avifArquivo = File('$pastaDestino/${marcaCode}_$cdProduto.avif');
    await avifArquivo.writeAsBytes(avifBytes);
    caminhoArquivo = '$pastaDestino/$avifArquivo';
    log('Diretório onde foi baixado $caminhoArquivo');
    log('Tamanho da imagem AVIF: ${avifBytes.length} bytes');

    setState(() {
      _originalImages.add(avifArquivo);
    });

    imagensBaixadasPorMarca[marcaCode] = (imagensBaixadasPorMarca[marcaCode] ?? 0) + 1;
  } catch (e) {
    log('Erro: $e');
  }
}


  // Future<void> baixarImagem(String urlImagem, cdProduto, cdMarca, int marcaCode) async {
  //   (context);
  //   try {
  //     final response = await http.get(Uri.parse(urlImagem));
  //     final bytes = response.bodyBytes;

  //     List<int> compressedBytes = await FlutterImageCompress.compressWithList(
  //       bytes,
  //       quality: 0,
  //     );

  //     final compressedSize = compressedBytes.length;
  //     log('Tamanho da imagem comprimida: $compressedSize bytes');

  //     final pastaDestino = '${diretorio.path}/produto';

  //     final nomeArquivo = '${cdMarca}_$cdProduto.jpg';
  //     final arquivoImagem = File('$pastaDestino/$nomeArquivo');

  //     await Directory(pastaDestino).create(recursive: true);

  //     if (arquivoImagem.existsSync()) {
  //       final dataModificacao = await arquivoImagem.lastModified();

  //       final dataAtual = DateTime.now();
  //       // log('dataAtual:$dataAtual');

  //       if (dataModificacao != dataAtual) {
  //         arquivoImagem.deleteSync();
  //         await arquivoImagem.writeAsBytes(compressedBytes);
  //         log('Nova imagem baixada com sucesso e salva em: ${arquivoImagem.path}');
  //       } else {
  //         log('A imagem já está atualizada. Não é necessário baixar novamente.');
  //       }
  //     } else {
  //       await arquivoImagem.writeAsBytes(compressedBytes);
  //       log('Imagem baixada com sucesso e salva em: ${arquivoImagem.path}');
  //     }
  //     imagensBaixadasPorMarca[marcaCode] = (imagensBaixadasPorMarca[marcaCode] ?? 0) + 1;
  //   } catch (e) {
  //     log('Erro ao baixar a imagem: $e');
  //   }

  //   Navigator.of(context).pop();
  //   setState(() {});
  // }

  Future<void> limparDiretorio(Directory diretorio) async {
    try {
      if (await diretorio.exists()) {
        await diretorio.delete(recursive: true);
        log('Conteúdo do diretório ${diretorio.path} excluído com sucesso.');
      } else {
        log('Diretório ${diretorio.path} não encontrado.');
      }
    } catch (e) {
      log('Erro ao limpar o diretório ${diretorio.path}: $e');
    }
  }


Widget _mostrarAvif(List<Map<String, dynamic>> produtos) {
  return Column(
    children: produtos.map((produto) {
      final nomeProduto = produto['nm_produto'];
      final cdMarca = produto['cd_marca'];
      log("${_originalImages.length}");

      return Container(
        child: Column(
          children: [
          if(_originalImages.isNotEmpty)...{
            for (int i = 0; i < _originalImages.length; i++) ...[
            Image.file(
              _originalImages[i],
              height: 300,
            ),
            SizedBox(height: 40),
            Text('Produto $nomeProduto - Marca $cdMarca'),
          ],}

          ],
        ),
      );
    }).toList(),
  );
}



  Widget buildCardForMarcas() {
    List<Widget> cards = [];

    for (final produto in listaProduto) {
      final marcaCode = int.parse(produto['cd_marca'].toString());

      if (!cards.any((card) => card.key == ValueKey(marcaCode))) {
        final imagensBaixadas = imagensBaixadasPorMarca[marcaCode] ?? 0;

        cards.add(
          ListTile(
            key: ValueKey(marcaCode),
            title: Row(
              children: [
                Expanded(
                  child: Text('${produto['nm_marca']}'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$imagensBaixadas / ${contarProdutosPorMarca(marcaCode)}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            leading: Checkbox(
              value: marcasSelecionadas.contains(marcaCode),
              onChanged: (value) {
                setState(() {
                  if (value!) {
                    marcasSelecionadas.add(marcaCode);
                  } else {
                    marcasSelecionadas.remove(marcaCode);
                  }
                });
              },
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(10.0),
          child: Align(
              child: Text(
            'ATENÇÃO!!!',
            style: TextStyle(color: Colors.red),
          )),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Text('Deixe marcado somente as marcas que deseja baixar as imagens.', style: TextStyle(color: Colors.grey.shade500)),
        ),
        const SizedBox(height: 6.0),
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1.0,
            ),
          cards[i],
        ],
      ],
    );
  }

  int contarProdutosPorMarca(int marcaCode) {
    int contador = 0;

    for (final produto in listaProduto) {
      final marcaProduto = int.parse(produto['cd_marca'].toString());
      if (marcaProduto == marcaCode) {
        contador++;
      }
    }

    return contador;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baixar Imagens'),
      ),
      body: ListView(
        children: [
          Padding(  
            padding: const EdgeInsets.all(8.0),
            child: Card(child: buildCardForMarcas()),
          ),
 _mostrarAvif(
          listaProduto
              .where((produto) => marcasSelecionadas.contains(int.parse(produto['cd_marca'].toString())))
              .toList(),
        ),        ],
      ),
      bottomNavigationBar: Row(
        children: [
          Expanded(
            child: ElevatedButton(
                onPressed: () {
                  pegarUrl();
                },
                child: const Icon(Icons.download)),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            child: ElevatedButton(
                onPressed: () {
                  limparDiretorio(diretorio);
                },
                child: const Icon(Icons.restore_from_trash)),
          )
        ],
      ),
    );
  }
}
