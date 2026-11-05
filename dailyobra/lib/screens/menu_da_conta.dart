import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/carteira_service.dart';
import '../services/perfil_service.dart';
import 'componentes.dart';
import 'marca_screen.dart';
import 'obras_screen.dart';
import 'propostas_comerciais_screen.dart';

/// As iniciais da pessoa, a mesma marca no topo, no menu e no perfil.
class AvatarDaConta extends StatelessWidget {
  const AvatarDaConta({
    super.key,
    required this.nome,
    this.tamanho = 44,
    this.cor,
    this.corDoTexto,
  });
  final String nome;
  final double tamanho;
  final Color? cor;
  final Color? corDoTexto;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: cor ?? c.acao),
      child: Text(
        LogoLoja.iniciais(nome.isEmpty ? '?' : nome),
        style: TextStyle(
          color: corDoTexto ?? c.textoSobreAcao,
          fontSize: tamanho * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// No celular abre por cima, com volta; nas telas largas é uma aba do menu lateral.
void abrirMinhasObras(BuildContext context) {
  if (formatoDoContexto(context) == Formato.celular) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ObrasScreen()),
    );
  } else {
    irParaAba(context, Aba.obras);
  }
}

Future<void> sairDaConta(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Sair da conta?'),
      content: const Text(
        'Suas obras, propostas e saldo continuam na conta. Para ver de novo, é só entrar.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Sair'),
        ),
      ],
    ),
  );
  if (ok == true) await AuthService.sair();
}

enum _Opcao { perfil, obras, carteira, propostas, marca, sair }

/// O avatar do topo abre a conta: quem está logado e os caminhos que dependem da pessoa, não de uma obra.
class MenuDaConta extends StatelessWidget {
  const MenuDaConta({super.key, this.cor, this.corDoTexto});
  final Color? cor;
  final Color? corDoTexto;

  void _escolher(BuildContext context, _Opcao opcao) {
    void abrir(Widget tela) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    }

    switch (opcao) {
      case _Opcao.perfil:
        irParaAba(context, Aba.perfil);
      case _Opcao.obras:
        abrirMinhasObras(context);
      case _Opcao.carteira:
        irParaAba(context, Aba.carteira);
      case _Opcao.propostas:
        abrir(const PropostasComerciaisScreen());
      case _Opcao.marca:
        abrir(const MarcaScreen());
      case _Opcao.sair:
        sairDaConta(context);
    }
  }

  PopupMenuItem<_Opcao> _item(
    BuildContext context,
    _Opcao opcao,
    IconData icone,
    String texto, {
    String? valor,
    Color? cor,
  }) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    return PopupMenuItem<_Opcao>(
      value: opcao,
      height: 44,
      child: Row(
        children: [
          Icon(icone, size: 20, color: cor ?? c.textoSuave),
          const SizedBox(width: Espaco.s3),
          Expanded(
            child: Text(
              texto,
              style: t.bodyMedium?.copyWith(color: cor ?? c.texto),
            ),
          ),
          if (valor != null)
            Text(
              valor,
              style: t.bodySmall?.copyWith(
                color: c.textoSuave,
                fontFeatures: numerosTabulares,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perfil = PerfilService.instance;
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    return PopupMenuButton<_Opcao>(
      tooltip: 'Sua conta',
      position: PopupMenuPosition.under,
      offset: const Offset(0, Espaco.s2),
      elevation: 8,
      color: c.superficie,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints.tightFor(width: 300),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
        side: BorderSide(color: c.borda),
      ),
      onSelected: (opcao) => _escolher(context, opcao),
      itemBuilder: (menu) => [
        PopupMenuItem<_Opcao>(
          enabled: false,
          height: 72,
          child: Row(
            children: [
              AvatarDaConta(nome: perfil.nome),
              const SizedBox(width: Espaco.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      perfil.nome.isEmpty ? 'Sua conta' : perfil.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(
                        color: c.texto,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      perfil.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: c.textoSuave),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        _item(menu, _Opcao.perfil, Icons.person_outline, 'Meu perfil'),
        _item(menu, _Opcao.obras, Icons.home_work_outlined, 'Minhas obras'),
        _item(
          menu,
          _Opcao.carteira,
          Icons.account_balance_wallet_outlined,
          'Carteira',
          valor: brl.format(CarteiraService.instance.disponivel),
        ),
        _item(
          menu,
          _Opcao.propostas,
          Icons.request_quote_outlined,
          'Propostas comerciais',
        ),
        _item(
          menu,
          _Opcao.marca,
          Icons.badge_outlined,
          'Sua marca nos documentos',
        ),
        const PopupMenuDivider(height: 1),
        _item(menu, _Opcao.sair, Icons.logout, 'Sair da conta', cor: c.erro),
      ],
      child: AvatarDaConta(nome: perfil.nome, cor: cor, corDoTexto: corDoTexto),
    );
  }
}
