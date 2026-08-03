import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'task_provider.dart';
import 'widgets/week_strip.dart';
import 'subject_provider.dart';
import 'stats_provider.dart';
import 'widgets/next_task_card.dart';
import 'task_model.dart';
import 'subject_model.dart';
import 'day_detail_screen.dart';
import 'subjects_screen.dart';
import 'add_task_screen.dart';
import 'widgets/task_tile.dart';
import 'stats_screen.dart';
import 'smart_plan_screen.dart';
import 'tap_scale.dart';
import 'widgets/hero_progress_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';

 
  late final ConfettiController _goalConfetti =
      ConfettiController(duration: const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(statsProvider.notifier).checkStreakBroken();
    });
  }

  @override
  void dispose() {
   
    _goalConfetti.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın! ☀️';
    if (hour < 18) return 'İyi günler! 👋';
    return 'İyi akşamlar! 🌙';
  }

  String _subGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Güne güzel bir başlangıç yapalım.';
    if (hour < 18) return 'Bugün çalışmaya hazır mısın?';
    return 'Günü kapatmadan son bir tur atalım mı?';
  }

 void _showGoalCelebration() {
  showDialog(
    context: context,
    barrierColor: Colors.black26,
    barrierDismissible: true,
    builder: (dialogContext) {

      Future.delayed(const Duration(seconds: 2), () {
        if (Navigator.canPop(dialogContext)) {
          Navigator.pop(dialogContext);
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _goalConfetti.play();
        }
      });

      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -40,
              child: ConfettiWidget(
                confettiController: _goalConfetti,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 24,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "🎉",
                    style: TextStyle(fontSize: 40),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Günlük hedef tamamlandı!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

  @override
 Widget build(BuildContext context) {
    final todayTasks = ref.watch(todayTasksProvider);
    final allTasks = ref.watch(taskProvider);
    final subjects = ref.watch(subjectProvider);
    final stats = ref.watch(statsProvider);

// "Sıradaki Görev": sadece bugüne değil, tüm görevler içinden
// zamanı planlanmış ve henüz tamamlanmamış en yakın olanı bulur.
// Böylece Akıllı Plan ile başka günlere dağıtılmış görevler de
// zamanı geldiğinde burada görünebilir.
final nextTask = allTasks
    .where((task) =>
        task.scheduledTime != null &&
        !task.isCompleted)
    .toList()
  ..sort((a, b) =>
      a.scheduledTime!.compareTo(b.scheduledTime!));

final upcomingTask = nextTask.isEmpty ? null : nextTask.first;
   ref.listen<int>(taskCompletionEventProvider, (previous, next) {
  if (previous != null && next > previous) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Görev tamamlandı!"),
        duration: Duration(seconds: 1),
      ),
    );
  }
});

    ref.listen<int>(goalReachedEventProvider, (previous, next) {
      if (previous != null && next > previous) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showGoalCelebration();
        });
      }
    });

    final completedCount = todayTasks.where((t) => t.isCompleted).length;
    final totalCount = todayTasks.length;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    final filteredTasks = _searchQuery.isEmpty
        ? todayTasks
        : todayTasks.where((t) => t.title.toLowerCase().contains(_searchQuery)).toList();

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(), style: AppTextStyles.heading1),
                          const SizedBox(height: 4),
                          Text(_subGreeting(), style: AppTextStyles.bodySecondary),
                        ],
                      ),
                    ),
                    TapScale(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const StatsScreen()),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: const Icon(Icons.bar_chart_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
HeroProgressCard(
  progress: progress,
  completedCount: completedCount,
  totalCount: totalCount,
  streak: stats.currentStreak,
),

const SizedBox(height: 16),

NextTaskCard(
  task: upcomingTask,
  subjects: subjects,
),

const SizedBox(height: 16),

WeekStrip(
  allTasks: allTasks,
  onDaySelected: (date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DayDetailScreen(date: date),
      ),
    );
  },
),
const SizedBox(height: 28),

Row(
              

               
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Derslerim', style: AppTextStyles.heading2),
                    TapScale(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SubjectsScreen()),
                        );
                      },
                      child: Text(
                        'Tümünü Gör',
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                subjects.isEmpty
                    ? _EmptyStateCard(
                        icon: Icons.menu_book_rounded,
                        message: 'Henüz ders eklemedin.\nHadi ilk dersini ekle!',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SubjectsScreen()),
                          );
                        },
                      )
                    : SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: subjects.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final subject = subjects[index];
                            return _SubjectPill(subject: subject);
                          },
                        ),
                      ),
                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bugünkü Görevler', style: AppTextStyles.heading2),
                    SizedBox(
                      width: 140,
                      height: 36,
                      child: TextField(
                        style: AppTextStyles.bodySecondary,
                        decoration: const InputDecoration(
                          hintText: 'Ara...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          contentPadding: EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value.toLowerCase()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                filteredTasks.isEmpty
                    ? (_searchQuery.isEmpty
                        ? const _EmptyStateCard(
                            icon: Icons.task_alt_rounded,
                            message: 'Bugün için görev yok.\nSağ alttaki butonla ekleyebilirsin.',
                          )
                        : Text('Sonuç bulunamadı', style: AppTextStyles.bodySecondary))
                    : Column(
                        children: filteredTasks
                            .map((task) => _AnimatedTaskEntry(
                                  key: ValueKey(task.id),
                                 child: TaskTile(task: task, subjects: subjects),
                                ))
                            .toList(),
                      ),
                const SizedBox(height: 80),
              ],
            ),
          ),
           ],
      ),
       
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'smart',
            backgroundColor: AppColors.success,
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            label: const Text('Akıllı Plan', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SmartPlanScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'task',
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Görev Ekle', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddTaskScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedTaskEntry extends StatefulWidget {
  final Widget child;

  const _AnimatedTaskEntry({super.key, required this.child});

  @override
  State<_AnimatedTaskEntry> createState() => _AnimatedTaskEntryState();
}

class _AnimatedTaskEntryState extends State<_AnimatedTaskEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: widget.child,
      ),
    );
  }
}




class _SubjectPill extends StatelessWidget {
  final SubjectModel subject;

  const _SubjectPill({required this.subject});

  @override
  Widget build(BuildContext context) {
    final color = Color(subject.colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            subject.name,
            style: AppTextStyles.bodySecondary.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onTap;

  const _EmptyStateCard({required this.icon, required this.message, this.onTap});

  @override
 Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );

    return onTap != null ? TapScale(onTap: onTap, child: content) : content;
  }
}