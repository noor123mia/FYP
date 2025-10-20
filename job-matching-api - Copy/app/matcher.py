import json
import numpy as np
import re
import os
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity
from difflib import SequenceMatcher
from typing import List, Dict, Any

# Set all cache directories to locations in /tmp
os.environ["TRANSFORMERS_CACHE"] = "/tmp/huggingface/transformers"
os.environ["HF_HOME"] = "/tmp/huggingface/hub"
os.environ["XDG_CACHE_HOME"] = "/tmp/huggingface/cache"


class JobCandidateMatchingSystem:
    def __init__(self, model_name="all-MiniLM-L6-v2"):
        """Initialize the matching system with a SBERT model."""
        # Create cache directories with proper permissions
        os.makedirs("/tmp/huggingface/transformers", exist_ok=True)
        os.makedirs("/tmp/huggingface/hub", exist_ok=True)
        os.makedirs("/tmp/huggingface/cache", exist_ok=True)

        print(f"Loading model: {model_name}")
        self.model = SentenceTransformer(model_name)
        print("Model loaded successfully!")

        # Define category weights
        self.weights = {
            "required_skills": 0.30,
            "qualification": 0.20,
            "work_experience": 0.25,
            "tech_stack": 0.20,
            "preferred_skills": 0.05
        }

        # Define keyword mappings for better matching
        self.education_keywords = {
            "bachelor": ["bscs", "bs", "bsc", "bachelor", "undergraduate", "degree"],
            "master": ["ms", "msc", "master", "graduate"],
            "computer science": [
                "computer science",
                "cs",
                "software engineering",
                "information technology",
                "it",
            ],
        }

    def convert_applied_candidate_format(self, applied_candidate: Dict[str, Any]) -> Dict[str, Any]:
        """Convert applied candidate format to the expected format for matching."""
        converted = {
            "id": applied_candidate.get("candidateId"),
            "name": applied_candidate.get("applicantName"),
            "email": applied_candidate.get("applicantEmail"),
            "phone": applied_candidate.get("applicantPhone"),
            "location": applied_candidate.get("location"),
            "summary": f"Applied for {applied_candidate.get('jobTitle', '')} at {applied_candidate.get('companyName', '')}",
            "technicalSkills": applied_candidate.get("technicalSkills", []),
            "softSkills": applied_candidate.get("softSkills", []),
            "languages": applied_candidate.get("languages", []),
            "educations": [],
            "workExperiences": applied_candidate.get("workExperiences", []),
            "certificates": [],
            "projects": []
        }

        # Convert education format
        if "educations" in applied_candidate and applied_candidate["educations"]:
            for edu in applied_candidate["educations"]:
                converted_edu = {
                    "degree": edu.get("degree"),
                    "field": edu.get("fieldOfStudy"),
                    "school": edu.get("institution"),
                    "startDate": edu.get("startYear"),
                    "endDate": edu.get("endYear")
                }
                converted["educations"].append(converted_edu)

        return converted

    def convert_job_format(self, job: Dict[str, Any]) -> Dict[str, Any]:
        """Convert job format to ensure consistency between different job structures."""
        converted = {
            "id": job.get("id"),
            "title": job.get("title"),
            "company_name": job.get("company_name"),
            "location": job.get("location"),
            "job_type": job.get("job_type"),
            "contract_type": job.get("contract_type"),
            "salary_range": job.get("salary_range"),
            "description": {}
        }

        # Handle different job description structures
        if "description" in job and isinstance(job["description"], dict):
            desc = job["description"]
            
            # First format - description contains everything
            if "position_summary" in desc:
                converted["description"]["position_summary"] = desc["position_summary"]
            if "responsibilities" in desc:
                converted["description"]["responsibilities"] = desc["responsibilities"]
            if "required_skills" in desc:
                converted["description"]["required_skills"] = desc["required_skills"]
            if "preferred_skills" in desc:
                converted["description"]["preferred_skills"] = desc["preferred_skills"]
            if "technical_skills" in desc:
                converted["description"]["technical_skills"] = desc["technical_skills"]
            if "what_we_offer" in desc:
                converted["description"]["what_we_offer"] = desc["what_we_offer"]
                
        # Handle direct fields (second format where fields are at root level)
        if "required_skills" in job:
            if "description" not in converted:
                converted["description"] = {}
            converted["description"]["required_skills"] = job["required_skills"]
        
        if "preferred_skills" in job:
            if "description" not in converted:
                converted["description"] = {}
            converted["description"]["preferred_skills"] = job["preferred_skills"]
            
        if "responsibilities" in job:
            if "description" not in converted:
                converted["description"] = {}
            converted["description"]["responsibilities"] = job["responsibilities"]
            
        if "technical_skills" in job:
            if "description" not in converted:
                converted["description"] = {}
            converted["description"]["technical_skills"] = job["technical_skills"]

        return converted

    def detect_duplicate_candidates(self, candidates: List[Dict[str, Any]], threshold: float = 0.85) -> List[Dict[str, Any]]:
        """Detect duplicate candidates based on similarity."""
        duplicates = []
        processed = set()

        for i, candidate1 in enumerate(candidates):
            if i in processed:
                continue

            duplicate_group = {
                "primary_candidate": candidate1,
                "candidates": [candidate1],
                "similarity_scores": []
            }

            for j, candidate2 in enumerate(candidates[i+1:], i+1):
                if j in processed:
                    continue

                similarity = self.compare_candidates(candidate1, candidate2)
                
                if similarity > threshold:
                    duplicate_group["candidates"].append(candidate2)
                    duplicate_group["similarity_scores"].append({
                        "candidate_index": j,
                        "similarity": similarity
                    })
                    processed.add(j)

            if len(duplicate_group["candidates"]) > 1:
                duplicates.append(duplicate_group)
                processed.add(i)

        return duplicates

    def compare_candidates(self, candidate1: Dict[str, Any], candidate2: Dict[str, Any]) -> float:
        """Compare two candidates and return similarity score."""
        similarity_scores = []

        # Name similarity
        name1 = candidate1.get("applicantName", "").lower().strip()
        name2 = candidate2.get("applicantName", "").lower().strip()
        name_similarity = SequenceMatcher(None, name1, name2).ratio()
        similarity_scores.append(name_similarity * 0.3)  # 30% weight

        # Email similarity
        email1 = candidate1.get("applicantEmail", "").lower().strip()
        email2 = candidate2.get("applicantEmail", "").lower().strip()
        if email1 and email2:
            email_similarity = 1.0 if email1 == email2 else 0.0
            similarity_scores.append(email_similarity * 0.4)  # 40% weight
        else:
            similarity_scores.append(0.0)

        # Phone similarity
        phone1 = candidate1.get("applicantPhone", "").strip()
        phone2 = candidate2.get("applicantPhone", "").strip()
        if phone1 and phone2:
            # Remove common phone formatting characters
            phone1_clean = re.sub(r'[\s\-\(\)\+]', '', phone1)
            phone2_clean = re.sub(r'[\s\-\(\)\+]', '', phone2)
            phone_similarity = 1.0 if phone1_clean == phone2_clean else 0.0
            similarity_scores.append(phone_similarity * 0.2)  # 20% weight
        else:
            similarity_scores.append(0.0)

        # Skills similarity
        skills1 = set(candidate1.get("technicalSkills", []) + candidate1.get("softSkills", []))
        skills2 = set(candidate2.get("technicalSkills", []) + candidate2.get("softSkills", []))
        
        if skills1 and skills2:
            skills_intersection = len(skills1.intersection(skills2))
            skills_union = len(skills1.union(skills2))
            skills_similarity = skills_intersection / skills_union if skills_union > 0 else 0.0
            similarity_scores.append(skills_similarity * 0.1)  # 10% weight
        else:
            similarity_scores.append(0.0)

        return sum(similarity_scores)

    def _get_text_embedding(self, text):
        """Convert text to embeddings using SBERT."""
        if not text:
            return None

        # If text is a list, convert to a single string
        if isinstance(text, list):
            text = " ".join(text)

        # Generate embedding
        return self.model.encode(text)

    def _calculate_similarity(self, embedding1, embedding2):
        """Calculate cosine similarity between two embeddings."""
        if embedding1 is None or embedding2 is None:
            return 0.0

        # Reshape embeddings for sklearn's cosine_similarity
        emb1 = embedding1.reshape(1, -1)
        emb2 = embedding2.reshape(1, -1)

        # Calculate and return cosine similarity
        return cosine_similarity(emb1, emb2)[0][0]

    def _calculate_keyword_similarity(self, text1, text2, boost_factor=0.2):
        """Calculate similarity based on keyword matching and boost the score."""
        if not text1 or not text2:
            return 0.0

        # Convert to lowercase for case-insensitive matching
        text1_lower = text1.lower()
        text2_lower = text2.lower()

        # Convert to sets of words for easier matching
        words1 = set(text1_lower.split())
        words2 = set(text2_lower.split())

        # Calculate overlap
        common_words = words1.intersection(words2)
        total_unique_words = words1.union(words2)

        # Jaccard similarity
        if len(total_unique_words) == 0:
            return 0.0

        return len(common_words) / len(total_unique_words) * boost_factor

    def _extract_job_required_skills(self, job_data):
        """Extract required skills from job data."""
        if "description" in job_data and "required_skills" in job_data["description"]:
            return " ".join(job_data["description"]["required_skills"])
        return ""

    def _extract_job_preferred_skills(self, job_data):
        """Extract preferred skills from job data."""
        if "description" in job_data and "preferred_skills" in job_data["description"]:
            return " ".join(job_data["description"]["preferred_skills"])
        return ""

    def _extract_job_summary(self, job_data):
        """Extract job summary from job data."""
        summary = ""
        if (
            "description" in job_data
            and job_data["description"]
            and "position_summary" in job_data["description"]
        ):
            summary = job_data["description"]["position_summary"]

        # Add title for better context
        if "title" in job_data:
            summary = job_data["title"] + ": " + summary

        # Add company name for additional context
        if "company_name" in job_data:
            summary = job_data["company_name"] + " - " + summary

        return summary

    def _extract_job_responsibilities(self, job_data):
        """Extract job responsibilities from job data."""
        if "description" in job_data and "responsibilities" in job_data["description"]:
            return " ".join(job_data["description"]["responsibilities"])
        return ""

    def _extract_job_tech_stack(self, job_data):
        """Extract technical stack from job data."""
        tech_stack_text = ""
        if "description" in job_data and "technical_skills" in job_data["description"]:
            for category, skills in job_data["description"]["technical_skills"].items():
                tech_stack_text += category + ": " + ", ".join(skills) + " "
        return tech_stack_text.strip()

    def _extract_job_qualifications(self, job_data):
        """Extract qualifications from job data."""
        qualifications = ""
        
        # First check required skills for education requirements
        if "description" in job_data and "required_skills" in job_data["description"]:
            for skill in job_data["description"]["required_skills"]:
                if any(
                    edu_term in skill.lower()
                    for edu_term in [
                        "degree",
                        "education",
                        "bachelor",
                        "master",
                        "phd",
                        "diploma",
                    ]
                ):
                    qualifications += skill + " "
        
        return qualifications.strip()

    def _extract_job_work_requirements(self, job_data):
        """Extract work experience requirements from job data."""
        experience_text = ""
        
        # Extract from required skills
        if "description" in job_data and "required_skills" in job_data["description"]:
            for skill in job_data["description"]["required_skills"]:
                if any(
                    exp_term in skill.lower()
                    for exp_term in [
                        "experience",
                        "years",
                        "year",
                        "yr",
                        "yrs",
                    ]
                ):
                    experience_text += skill + " "
        
        # Also include job type and contract type for better matching
        if "job_type" in job_data:
            experience_text += f"Job type: {job_data['job_type']} "
        
        if "contract_type" in job_data:
            experience_text += f"Contract: {job_data['contract_type']} "
        
        return experience_text.strip()

    def _extract_candidate_skills(self, candidate_data):
        """Extract candidate skills from candidate data."""
        skills_text = ""

        # Technical skills
        if "technicalSkills" in candidate_data and candidate_data["technicalSkills"]:
            skills_text += (
                "Technical Skills: "
                + ", ".join(candidate_data["technicalSkills"])
                + " "
            )

        # Soft skills
        if "softSkills" in candidate_data and candidate_data["softSkills"]:
            skills_text += (
                "Soft Skills: " + ", ".join(candidate_data["softSkills"]) + " "
            )

        # Add certificates as they often indicate skills
        if "certificates" in candidate_data and candidate_data["certificates"]:
            for cert in candidate_data["certificates"]:
                skills_text += f"Certificate: {cert.get('name', '')} "

        return skills_text.strip()

    def _extract_candidate_education(self, candidate_data):
        """Extract candidate education from candidate data."""
        education_text = ""
        if "educations" in candidate_data and candidate_data["educations"]:
            for edu in candidate_data["educations"]:
                education_text += f"{edu.get('degree', '')} in {edu.get('field', '')} from {edu.get('school', '')}. "
        return education_text.strip()

    def _extract_candidate_summary(self, candidate_data):
        """Extract candidate summary from candidate data."""
        summary = ""
        if "summary" in candidate_data and candidate_data["summary"]:
            summary = candidate_data["summary"]

        # Add name and any workExperience titles for better context
        if "name" in candidate_data:
            summary = candidate_data["name"] + ": " + summary

        # Add most recent work title if available
        if "workExperiences" in candidate_data and candidate_data["workExperiences"]:
            latest_title = candidate_data["workExperiences"][0].get("title", "")
            if latest_title:
                summary += f" Current position: {latest_title}"

        return summary

    def _extract_candidate_work_experience(self, candidate_data):
        """Extract candidate work experience from candidate data."""
        experience_text = ""

        # Add years of experience from summary if available
        if (
            "summary" in candidate_data
            and candidate_data["summary"]
            and "experience" in candidate_data["summary"].lower()
        ):
            experience_text += candidate_data["summary"] + " "

        # Add work experiences
        if "workExperiences" in candidate_data and candidate_data["workExperiences"]:
            for exp in candidate_data["workExperiences"]:
                experience_text += f"{exp.get('title', '')} at {exp.get('company', '')}. {exp.get('description', '')} "

        # Include projects as they can indicate practical experience
        if "projects" in candidate_data and candidate_data["projects"]:
            for project in candidate_data["projects"]:
                experience_text += f"Project: {project.get('title', '')}. {project.get('description', '')} "

        return experience_text.strip()

    def _extract_individual_skills(self, skills_text):
        """Extract individual skills from a skills text."""
        if not skills_text:
            return set()

        # Remove common prefixes
        skills_text = skills_text.lower()
        skills_text = skills_text.replace("technical skills:", "").replace(
            "soft skills:", ""
        )

        # Split by commas and clean up
        skills = [s.strip() for s in skills_text.split(",")]

        # Remove empty strings
        skills = [s for s in skills if s]

        return set(skills)

    def _calculate_direct_skill_match(self, job_skills_text, candidate_skills_text):
        """Calculate direct skill match percentage based on individual skills."""
        # Extract individual skills
        job_skills = self._extract_individual_skills(job_skills_text)
        candidate_skills = self._extract_individual_skills(candidate_skills_text)

        if not job_skills or not candidate_skills:
            return 0.0

        # Count matches
        matches = 0
        for job_skill in job_skills:
            for candidate_skill in candidate_skills:
                # Check for exact match or if job skill is a substring of candidate skill or vice versa
                if (
                    job_skill == candidate_skill
                    or job_skill in candidate_skill
                    or candidate_skill in job_skill
                ):
                    matches += 1
                    break

        # Calculate match percentage
        return matches / len(job_skills) if len(job_skills) > 0 else 0.0

    def calculate_match_score(self, job_data, candidate_data):
        """Calculate the match score between a job and a candidate."""
        # Process job data
        job_required_skills = self._extract_job_required_skills(job_data)
        job_preferred_skills = self._extract_job_preferred_skills(job_data)
        job_summary = self._extract_job_summary(job_data)
        job_responsibilities = self._extract_job_responsibilities(job_data)
        job_qualifications = self._extract_job_qualifications(job_data)
        job_tech_stack = self._extract_job_tech_stack(job_data)
        job_work_requirements = self._extract_job_work_requirements(job_data)

        # Process candidate data
        candidate_skills = self._extract_candidate_skills(candidate_data)
        candidate_education = self._extract_candidate_education(candidate_data)
        candidate_summary = self._extract_candidate_summary(candidate_data)
        candidate_experience = self._extract_candidate_work_experience(candidate_data)

        # Create embeddings for job data
        job_required_skills_embedding = self._get_text_embedding(job_required_skills)
        job_preferred_skills_embedding = self._get_text_embedding(job_preferred_skills)
        job_responsibilities_embedding = self._get_text_embedding(job_responsibilities)
        job_qualifications_embedding = self._get_text_embedding(job_qualifications)
        job_tech_stack_embedding = self._get_text_embedding(job_tech_stack)
        job_work_requirements_embedding = self._get_text_embedding(job_work_requirements)

        # Create embeddings for candidate data
        candidate_skills_embedding = self._get_text_embedding(candidate_skills)
        candidate_education_embedding = self._get_text_embedding(candidate_education)
        candidate_experience_embedding = self._get_text_embedding(candidate_experience)

        # Calculate similarities for each category using embeddings
        category_scores = {}

        # Required Skills - combine embedding similarity with direct skill matching
        embedding_similarity = self._calculate_similarity(
            job_required_skills_embedding, candidate_skills_embedding
        )
        direct_skill_match = self._calculate_direct_skill_match(
            job_required_skills, candidate_skills
        )

        # Weight direct matching higher for skills
        category_scores["required_skills"] = (
            0.3 * embedding_similarity + 0.7 * direct_skill_match
        )

        # Preferred Skills - add as a new category
        if job_preferred_skills:
            pref_embedding_similarity = self._calculate_similarity(
                job_preferred_skills_embedding, candidate_skills_embedding
            )
            pref_direct_skill_match = self._calculate_direct_skill_match(
                job_preferred_skills, candidate_skills
            )
            
            category_scores["preferred_skills"] = (
                0.3 * pref_embedding_similarity + 0.7 * pref_direct_skill_match
            )
        else:
            category_scores["preferred_skills"] = 0.0

        # Qualification - check for degree match
        qual_embedding_similarity = self._calculate_similarity(
            job_qualifications_embedding, candidate_education_embedding
        )

        # Boost score if there's a CS degree match
        has_cs_degree = False
        if "educations" in candidate_data:
            for edu in candidate_data["educations"]:
                degree = edu.get("degree", "").lower()
                field = edu.get("field", "").lower()

                if any(
                    d in degree for d in self.education_keywords["bachelor"]
                ) and any(
                    f in field for f in self.education_keywords["computer science"]
                ):
                    has_cs_degree = True
                    break

        category_scores["qualification"] = qual_embedding_similarity
        if (
            has_cs_degree
            and job_qualifications
            and "bachelor" in job_qualifications.lower()
            and "computer science" in job_qualifications.lower()
        ):
            category_scores["qualification"] = max(
                0.8, category_scores["qualification"]
            )  # Increased boost

        # Work Experience - check years of experience against requirements
        exp_embedding_similarity = self._calculate_similarity(
            job_work_requirements_embedding, candidate_experience_embedding
        )
        
        responsibilities_match = self._calculate_similarity(
            job_responsibilities_embedding, candidate_experience_embedding
        )
        
        # Combine the two work experience metrics with responsibilities having higher weight
        exp_combined_score = 0.4 * exp_embedding_similarity + 0.6 * responsibilities_match

        # Extract years of experience required from job data
        years_of_exp_required = 0
        if "description" in job_data and "required_skills" in job_data["description"]:
            for skill in job_data["description"]["required_skills"]:
                if "year" in skill.lower() and "experience" in skill.lower():
                    # Extract number of years required
                    years_match = re.search(
                        r"(\d+)[\+]?\s*(?:years?|yrs?)", skill.lower()
                    )
                    if years_match:
                        years_of_exp_required = int(years_match.group(1))

        years_of_exp_candidate = 0
        if "summary" in candidate_data:
            years_match = re.search(
                r"(\d+)[\+]?\s*(?:years?|yrs?)", candidate_data["summary"].lower()
            )
            if years_match:
                years_of_exp_candidate = int(years_match.group(1))

        # Calculate total years from work experiences
        total_years = 0
        if "workExperiences" in candidate_data and candidate_data["workExperiences"]:
            for exp in candidate_data["workExperiences"]:
                if "durationInMonths" in exp:
                    total_years += exp.get("durationInMonths", 0) / 12

        # Use the maximum of explicit years mentioned or calculated total
        years_of_exp_candidate = max(years_of_exp_candidate, total_years)

        # Set the work experience score
        category_scores["work_experience"] = exp_combined_score
        
        # Boost work experience score if candidate meets or exceeds required years
        if years_of_exp_required > 0 and years_of_exp_candidate >= years_of_exp_required:
            category_scores["work_experience"] = max(0.8, category_scores["work_experience"])

        # Tech Stack - combine embedding similarity with direct skill matching
        tech_embedding_similarity = self._calculate_similarity(
            job_tech_stack_embedding, candidate_skills_embedding
        )
        tech_direct_match = self._calculate_direct_skill_match(
            job_tech_stack, candidate_skills
        )

        # Increased weight for direct matching in tech stack
        category_scores["tech_stack"] = (
            0.3 * tech_embedding_similarity + 0.7 * tech_direct_match
        )

        # Add job type match bonus
        # Check if job type matches candidate's preference or recent job types
        job_type_match = False
        if (
            "job_type" in job_data 
            and "workExperiences" in candidate_data 
            and candidate_data["workExperiences"]
        ):
            job_type = job_data["job_type"].lower()
            
            # Check recent experiences for matching job type
            for exp in candidate_data["workExperiences"][:2]:  # Consider only most recent 2
                if "jobType" in exp and job_type in exp["jobType"].lower():
                    job_type_match = True
                    break
        
        # Apply job type bonus
        if job_type_match:
            # Small boost to overall score for job type match
            job_type_bonus = 0.05
        else:
            job_type_bonus = 0.0

        # Calculate weighted average
        total_score = 0
        applicable_weight_sum = 0

        for category, score in category_scores.items():
            if score > 0:  # Only include non-zero scores
                total_score += score * self.weights[category]
                applicable_weight_sum += self.weights[category]

        # Normalize by applicable weights
        overall_match_score = (
            total_score / applicable_weight_sum if applicable_weight_sum > 0 else 0
        )
        
        # Add the job type bonus to the overall score
        overall_match_score += job_type_bonus

        # Format category scores as percentages
        for category in category_scores:
            category_scores[category] = float(round(category_scores[category] * 100, 2))

        # Scale up the overall match score
        scaling_factor = 1.1  # This will help push the scores higher
        overall_match_percentage = float(
            min(100, round(overall_match_score * 100 * scaling_factor, 2))
        )

        # Return the match scores
        return {
            "overall_match_score": overall_match_percentage,
            "category_scores": category_scores,
        }

    def get_matching_skills(self, job_data, candidate_data):
        """Get the matching skills between a job and a candidate."""
        # Extract required skills from job
        required_skills = []
        if "description" in job_data and "required_skills" in job_data["description"]:
            required_skills = job_data["description"]["required_skills"]
            
        # Add preferred skills
        if "description" in job_data and "preferred_skills" in job_data["description"]:
            required_skills.extend(job_data["description"]["preferred_skills"])

        # Extract tech stack skills
        if "description" in job_data and "technical_skills" in job_data["description"]:
            for category, skills in job_data["description"]["technical_skills"].items():
                required_skills.extend(skills)

        # Extract candidate skills
        candidate_skills = []
        if "technicalSkills" in candidate_data and candidate_data["technicalSkills"]:
            candidate_skills.extend(candidate_data["technicalSkills"])
            
        # Add soft skills
        if "softSkills" in candidate_data and candidate_data["softSkills"]:
            candidate_skills.extend(candidate_data["softSkills"])

        # Find matching skills
        matching_skills = []
        for job_skill in required_skills:
            for candidate_skill in candidate_skills:
                if (
                    job_skill.lower() in candidate_skill.lower()
                    or candidate_skill.lower() in job_skill.lower()
                ):
                    matching_skills.append(candidate_skill)
                    break

        return list(set(matching_skills))  # Remove duplicates "