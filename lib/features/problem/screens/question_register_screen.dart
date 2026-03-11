import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/question_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/question_provider.dart';

class QuestionRegisterScreen extends ConsumerStatefulWidget {
  const QuestionRegisterScreen({super.key});

  @override
  ConsumerState<QuestionRegisterScreen> createState() =>
      _QuestionRegisterScreenState();
}

class _QuestionRegisterScreenState
    extends ConsumerState<QuestionRegisterScreen> {
  int _step = 0; // 0~5
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _uniCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final state = ref.read(questionRegisterProvider);
    _priceCtrl.text = state.price.toString();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _priceCtrl.dispose();
    _uniCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 5) setState(() => _step++);
  }

  void _prev() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _pickImages() async {
    final state = ref.read(questionRegisterProvider);
    if (state.imageUrls.length >= 5) return;
    final images = await _picker.pickMultiImage(limit: 5 - state.imageUrls.length);
    if (images.isEmpty) return;
    // TODO: upload to Supabase Storage and get URLs
    // For now, store local paths for display
    final paths = images.map((x) => x.path).toList();
    ref.read(questionRegisterProvider.notifier).setBody(state.body);
    showAppToast(context, '이미지 ${paths.length}장 추가됨', type: ToastType.info);
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final form = ref.read(questionRegisterProvider);
    if (form.body.trim().isEmpty) {
      showAppToast(context, '질문 내용을 입력해 주세요', type: ToastType.error);
      return;
    }
    if (user.cashBalance < form.price) {
      _showInsufficientCash();
      return;
    }

    final qId = await ref
        .read(questionSubmitProvider.notifier)
        .submit(form, user.id);

    if (!mounted) return;
    if (qId != null) {
      ref.read(questionRegisterProvider.notifier).reset();
      showAppToast(context, '질문이 등록됐어요!', type: ToastType.success);
      context.go('/student/question/$qId');
    } else {
      showAppToast(context, AppStrings.serverError, type: ToastType.error);
    }
  }

  void _showInsufficientCash() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.bottomSheetRadius)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: AppColors.warning),
            const SizedBox(height: AppSpacing.base),
            Text(AppStrings.notEnoughCash, style: AppTypography.title3),
            const SizedBox(height: AppSpacing.sm),
            Text('캐시를 충전한 후 질문을 등록해 주세요',
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: AppStrings.chargeCash,
              onPressed: () {
                Navigator.pop(context);
                context.push('/cash/charge');
              },
            ),
            const SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questionRegisterProvider);
    final isSubmitting = ref.watch(questionSubmitProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppStrings.registerQuestion,
          style: AppTypography.title3,
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _ProgressBar(step: _step, total: 6),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _Step1SchoolLevel(state: state),
                    1 => _Step2Subject(state: state),
                    2 => _Step3Content(
                        state: state,
                        titleCtrl: _titleCtrl,
                        bodyCtrl: _bodyCtrl,
                        onPickImages: _pickImages,
                      ),
                    3 => _Step4Price(
                        state: state,
                        priceCtrl: _priceCtrl,
                      ),
                    4 => _Step5Filter(state: state, uniCtrl: _uniCtrl),
                    5 => _Step6Confirm(state: state),
                    _ => const SizedBox(),
                  },
                ),
              ),
            ),
            _BottomNav(
              step: _step,
              canNext: _canNext(state),
              isLoading: isSubmitting,
              onPrev: _step > 0 ? _prev : null,
              onNext: _step < 5 ? _next : _submit,
            ),
          ],
        ),
      ),
    );
  }

  bool _canNext(QuestionRegisterState s) {
    return switch (_step) {
      2 => s.body.trim().isNotEmpty,
      3 => s.price > 0,
      _ => true,
    };
  }
}

// ── 스텝 1: 학교급 선택 ────────────────────────────────────────────
class _Step1SchoolLevel extends ConsumerWidget {
  const _Step1SchoolLevel({required this.state});
  final QuestionRegisterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(questionRegisterProvider.notifier);
    final levels = [
      (SchoolLevel.elementary, AppStrings.elementary),
      (SchoolLevel.middle, AppStrings.middle),
      (SchoolLevel.high, AppStrings.high),
      (SchoolLevel.etc, AppStrings.etc),
    ];
    return _StepBody(
      title: AppStrings.schoolLevel,
      subtitle: '선택 사항이에요',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: levels.map((pair) {
          final (level, label) = pair;
          final selected = state.schoolLevel == level;
          return _SelectChip(
            label: label,
            selected: selected,
            onTap: () => n.setSchoolLevel(selected ? null : level),
          );
        }).toList(),
      ),
    );
  }
}

// ── 스텝 2: 과목 선택 ─────────────────────────────────────────────
class _Step2Subject extends ConsumerWidget {
  const _Step2Subject({required this.state});
  final QuestionRegisterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(questionRegisterProvider.notifier);
    final subjects = [
      (QuestionSubject.math, AppStrings.subjectMath),
      (QuestionSubject.korean, AppStrings.subjectKorean),
      (QuestionSubject.english, AppStrings.subjectEnglish),
      (QuestionSubject.science, AppStrings.subjectScience),
      (QuestionSubject.social, AppStrings.subjectSocial),
      (QuestionSubject.etc, AppStrings.subjectEtc),
    ];
    return _StepBody(
      title: AppStrings.subject,
      subtitle: '선택 사항이에요',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: subjects.map((pair) {
          final (sub, label) = pair;
          final selected = state.subject == sub;
          return _SelectChip(
            label: label,
            selected: selected,
            onTap: () => n.setSubject(selected ? null : sub),
          );
        }).toList(),
      ),
    );
  }
}

// ── 스텝 3: 질문 내용 ─────────────────────────────────────────────
class _Step3Content extends ConsumerWidget {
  const _Step3Content({
    required this.state,
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.onPickImages,
  });
  final QuestionRegisterState state;
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final VoidCallback onPickImages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(questionRegisterProvider.notifier);
    return _StepBody(
      title: AppStrings.questionBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: titleCtrl,
            onChanged: n.setTitle,
            maxLength: 60,
            decoration: _inputDeco(AppStrings.questionTitleHint),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: bodyCtrl,
            onChanged: n.setBody,
            maxLines: 6,
            decoration: _inputDeco(AppStrings.questionBodyHint),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: onPickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.accent),
            label: Text(
              '${AppStrings.addImage} (${state.imageUrls.length}/5)',
              style: AppTypography.subhead
                  .copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            AppTypography.callout.copyWith(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.all(AppSpacing.base),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      );
}

// ── 스텝 4: 가격 설정 ─────────────────────────────────────────────
class _Step4Price extends ConsumerWidget {
  const _Step4Price({required this.state, required this.priceCtrl});
  final QuestionRegisterState state;
  final TextEditingController priceCtrl;

  void _adjust(int delta, WidgetRef ref) {
    final n = ref.read(questionRegisterProvider.notifier);
    n.adjustPrice(delta);
    priceCtrl.text = ref.read(questionRegisterProvider).price.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(questionRegisterProvider.notifier);
    return _StepBody(
      title: AppStrings.priceTitle,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          GestureDetector(
            onTap: () => FocusScope.of(context).requestFocus(),
            child: TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: AppTypography.display
                  .copyWith(color: AppColors.accent),
              onChanged: (v) {
                final parsed = int.tryParse(v) ?? 0;
                n.setPrice(parsed);
              },
              decoration: InputDecoration(
                prefixText: '₩ ',
                prefixStyle: AppTypography.title2
                    .copyWith(color: AppColors.accent),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [-1000, -500, -100, 100, 500, 1000].map((delta) {
              return GestureDetector(
                onTap: () => _adjust(delta, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.chipRadius),
                    color: AppColors.card,
                  ),
                  child: Text(
                    delta > 0 ? '+$delta' : '$delta',
                    style: AppTypography.footnote.copyWith(
                      color: delta > 0
                          ? AppColors.accent
                          : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.x2l),
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.mathBlock,
              borderRadius:
                  BorderRadius.circular(AppSpacing.inputRadius),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '이 가격대 평균 답변 시간: 약 15분',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 스텝 5: 멘토 필터 ─────────────────────────────────────────────
class _Step5Filter extends ConsumerWidget {
  const _Step5Filter({required this.state, required this.uniCtrl});
  final QuestionRegisterState state;
  final TextEditingController uniCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(questionRegisterProvider.notifier);
    return _StepBody(
      title: AppStrings.mentorFilter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterOption(
            label: AppStrings.filterAll,
            desc: '모든 멘토가 답변할 수 있어요',
            selected: state.filterType == MentorFilterType.all,
            onTap: () => n.setFilterType(MentorFilterType.all),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FilterOption(
            label: AppStrings.filterCondition,
            desc: '인증 조건을 충족하는 멘토만',
            selected: state.filterType == MentorFilterType.condition,
            onTap: () => n.setFilterType(MentorFilterType.condition),
          ),
          if (state.filterType == MentorFilterType.condition) ...[
            const SizedBox(height: AppSpacing.base),
            ...state.certConditions.asMap().entries.map(
                  (e) => Chip(
                    label: Text(e.value.label,
                        style: AppTypography.footnote),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => n.removeCertCondition(e.key),
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                  ),
                ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _showAddConditionSheet(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppStrings.addCertCondition),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.chipRadius),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text('대학교 필터 (AND 조건)',
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textSub)),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: uniCtrl,
              onChanged: (v) => n.setRequireUniversity(
                  v.trim().isEmpty ? null : v.trim()),
              decoration: InputDecoration(
                hintText: AppStrings.universityFilter,
                hintStyle: AppTypography.callout
                    .copyWith(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(
                      color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddConditionSheet(BuildContext context, WidgetRef ref) {
    String? selectedSubject;
    CertFilterLevel selectedLevel = CertFilterLevel.proOrAbove;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.bottomSheetRadius)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.base,
            right: AppSpacing.base,
            top: AppSpacing.xl,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.x2l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text('인증 조건 추가', style: AppTypography.title3),
              const SizedBox(height: AppSpacing.base),
              Text('과목', style: AppTypography.subhead),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: selectedSubject,
                hint: Text('과목을 선택하세요',
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textDisabled)),
                items: AppStrings.certSubjects
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) =>
                    setModalState(() => selectedSubject = v),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text('최소 등급', style: AppTypography.subhead),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _LevelChip(
                      label: AppStrings.proOrAbove,
                      selected:
                          selectedLevel == CertFilterLevel.proOrAbove,
                      onTap: () => setModalState(() =>
                          selectedLevel = CertFilterLevel.proOrAbove),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _LevelChip(
                      label: AppStrings.masterOnly,
                      selected:
                          selectedLevel == CertFilterLevel.masterOnly,
                      onTap: () => setModalState(() =>
                          selectedLevel = CertFilterLevel.masterOnly),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: '추가',
                onPressed: selectedSubject == null
                    ? null
                    : () {
                        ref
                            .read(questionRegisterProvider.notifier)
                            .addCertCondition(CertCondition(
                              subject: selectedSubject!,
                              minLevel: selectedLevel,
                            ));
                        Navigator.pop(ctx);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.subhead.copyWith(
              color: selected ? Colors.white : AppColors.textSub,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 스텝 6: 등록 확인 ─────────────────────────────────────────────
class _Step6Confirm extends ConsumerWidget {
  const _Step6Confirm({required this.state});
  final QuestionRegisterState state;

  String _format(int v) => v
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(cashBalanceProvider);
    final after = balance - state.price;

    return _StepBody(
      title: AppStrings.questionConfirmTitle,
      child: Column(
        children: [
          _ConfirmRow(
            label: AppStrings.willDeduct,
            value: '₩${_format(state.price)}',
            valueColor: AppColors.error,
          ),
          const Divider(height: 24, color: AppColors.divider),
          _ConfirmRow(
            label: AppStrings.currentBalance,
            value: '₩${_format(balance)}',
          ),
          _ConfirmRow(
            label: AppStrings.afterBalance,
            value: '₩${_format(after)}',
            valueColor: after < 0 ? AppColors.error : AppColors.success,
          ),
          if (after < 0) ...[
            const SizedBox(height: AppSpacing.base),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(AppStrings.notEnoughCash,
                      style: AppTypography.footnote
                          .copyWith(color: AppColors.error)),
                ],
              ),
            ),
          ],
          if (state.title?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xl),
            _ConfirmRow(label: '제목', value: state.title!),
          ],
          const SizedBox(height: AppSpacing.sm),
          _ConfirmRow(
            label: '내용',
            value: state.body.length > 50
                ? '${state.body.substring(0, 50)}...'
                : state.body,
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub)),
          Flexible(
            child: Text(
              value,
              style: AppTypography.calloutBold.copyWith(
                color: valueColor ?? AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공통 컴포넌트 ────────────────────────────────────────────────
class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.title,
    required this.child,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.title2),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!,
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
          ],
          const SizedBox(height: AppSpacing.x2l),
          child,
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.border),
          boxShadow: selected ? [] : AppSpacing.cardShadow,
        ),
        child: Text(
          label,
          style: AppTypography.subhead.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.desc,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.05)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.accent : AppColors.textDisabled,
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.subhead.copyWith(
                      color: selected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                Text(desc,
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textSub)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: (step + 1) / total,
      backgroundColor: AppColors.border,
      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
      minHeight: 3,
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.step,
    required this.canNext,
    required this.isLoading,
    required this.onNext,
    this.onPrev,
  });
  final int step;
  final bool canNext;
  final bool isLoading;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (onPrev != null)
            Expanded(
              flex: 1,
              child: AppButton(
                label: AppStrings.back,
                variant: AppButtonVariant.secondary,
                onPressed: onPrev,
                height: AppSpacing.buttonHeightSm,
              ),
            ),
          if (onPrev != null) const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: AppButton(
              label: step == 5 ? AppStrings.registerNow : AppStrings.next,
              onPressed: canNext && !isLoading ? onNext : null,
              isLoading: isLoading,
              height: AppSpacing.buttonHeightSm,
            ),
          ),
        ],
      ),
    );
  }
}
