import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vuleadtaxi/SkillUploadScreen.dart';

class Skill {
  final int skillId;
  final String skillName;
  final String? skillType;
  final String? skillDescription;
  final String? skillIcon;
  bool isSelected;

  Skill({
    required this.skillId,
    required this.skillName,
    this.skillType,
    this.skillDescription,
    this.skillIcon,
    this.isSelected = false,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      skillId: json['Skill_ID'],
      skillName: json['Skill_Name'],
      skillType: json['Skill_Type'],
      skillDescription: json['Skill_Description'] ?? 'No description available',
      skillIcon: json['Skill_Icon'],
    );
  }
}

class SkillSelectionScreen extends StatefulWidget {
  const SkillSelectionScreen({Key? key}) : super(key: key);

  @override
  State<SkillSelectionScreen> createState() => _SkillSelectionScreenState();
}

class _SkillSelectionScreenState extends State<SkillSelectionScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<Skill> _skills = [];
  List<Skill> _filteredSkills = [];
  Skill? _selectedSkill;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  String _selectedFilter = 'All';
  List<String> _skillTypes = ['All'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _fetchSkills();
    _searchController.addListener(_filterSkills);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _filterSkills() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty && _selectedFilter == 'All') {
        _filteredSkills = _skills;
      } else {
        _filteredSkills = _skills.where((skill) {
          final matchesQuery = skill.skillName.toLowerCase().contains(query);
          final matchesFilter = _selectedFilter == 'All' || skill.skillType == _selectedFilter;
          return matchesQuery && matchesFilter;
        }).toList();
      }
    });
  }

  Future<void> _fetchSkills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/skills'),
      );

      print('Skills API response status: ${response.statusCode}');
      print('Skills API response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] != null) {
          final List<dynamic> skillsJson = responseData['data'];
          setState(() {
            _skills = skillsJson.map((skill) => Skill.fromJson(skill)).toList();
            _filteredSkills = _skills;
            _isLoading = false;

            // Extract unique skill types for filtering
            final Set<String> skillTypesSet = Set<String>();
            for (var skill in _skills) {
              if (skill.skillType != null && skill.skillType!.isNotEmpty) {
                skillTypesSet.add(skill.skillType!);
              }
            }
            _skillTypes = ['All', ...skillTypesSet.toList()];
          });

          _animationController.forward();
          print('Skills fetched: ${_skills.length}');
          print('Skill types: $_skillTypes');
        } else {
          setState(() {
            _errorMessage = 'No skills found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load skills. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
      print('Exception when fetching skills: $e');
    }
  }

  Future<void> _continueToUpload() async {
    if (_selectedSkill == null) {
      setState(() {
        _errorMessage = 'Please select a skill';
      });
      return;
    }

    // Save Skill_ID to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('Skill_ID', _selectedSkill!.skillId);
    print('Saved Skill_ID: ${_selectedSkill!.skillId}');

    // Navigate to skill upload screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SkillUploadScreen(
            skillName: _selectedSkill!.skillName,
          ),
        ),
      );
    }
  }

  void _selectSkill(Skill skill) {
    setState(() {
      _selectedSkill = skill;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Skill',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchSkills,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFE89D43),
          ),
        )
            : Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header and description
              FadeTransition(
                opacity: _animation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Your Skill',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the skill you want to add to your profile',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),


              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search skills',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Filter chips
              if (_skillTypes.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _skillTypes.map((type) {
                      final isSelected = _selectedFilter == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(
                            type,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = type;
                              _filterSkills();
                            });
                          },
                          backgroundColor: Colors.white.withOpacity(0.05),
                          selectedColor: const Color(0xFFE89D43).withOpacity(0.3),
                          checkmarkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFFE89D43)
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),

              // Skills list
              Expanded(
                child: _filteredSkills.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No skills found',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _selectedFilter = 'All';
                            _filteredSkills = _skills;
                          });
                        },
                        child: const Text(
                          'Clear filters',
                          style: TextStyle(
                            color: Color(0xFFE89D43),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _filteredSkills.length,
                  itemBuilder: (context, index) {
                    final skill = _filteredSkills[index];
                    final isSelected = _selectedSkill?.skillId == skill.skillId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () => _selectSkill(skill),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE89D43).withOpacity(0.15)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFE89D43)
                                  : Colors.white.withOpacity(0.1),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE89D43).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    _getIconForSkill(skill.skillType),
                                    color: const Color(0xFFE89D43),
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      skill.skillName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (skill.skillType != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          skill.skillType!,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFE89D43),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Info text about selection
              if (_selectedSkill != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE89D43).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE89D43).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFFE89D43),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You have selected "${_selectedSkill!.skillName}". Click continue to proceed with adding this skill.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Continue Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE89D43).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _continueToUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE89D43),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedSkill == null ? 'Select a Skill' : 'Continue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForSkill(String? skillType) {
    if (skillType == null) return Icons.build;

    switch (skillType.toLowerCase()) {
      case 'technical':
        return Icons.code;
      case 'soft skill':
        return Icons.people;
      case 'leadership':
        return Icons.trending_up;
      case 'language':
        return Icons.language;
      case 'design':
        return Icons.brush;
      case 'marketing':
        return Icons.campaign;
      case 'analytics':
        return Icons.analytics;
      default:
        return Icons.star;
    }
  }
}