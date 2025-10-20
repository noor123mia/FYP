# models.py
from typing import List, Dict, Optional, Any
from pydantic import BaseModel

class Education(BaseModel):
    degree: Optional[str] = None
    field: Optional[str] = None
    school: Optional[str] = None
    startDate: Optional[str] = None
    endDate: Optional[str] = None
    gpa: Optional[str] = None

class WorkExperience(BaseModel):
    title: Optional[str] = None
    company: Optional[str] = None
    description: Optional[str] = None
    startDate: Optional[str] = None
    endDate: Optional[str] = None
    location: Optional[str] = None

class Certificate(BaseModel):
    name: Optional[str] = None
    issuer: Optional[str] = None
    date: Optional[str] = None
    credentialId: Optional[str] = None
    link: Optional[str] = None

class Project(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    date: Optional[str] = None
    link: Optional[str] = None

class Candidate(BaseModel):
    id: Optional[str] = None
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    location: Optional[str] = None
    summary: Optional[str] = None
    profilePicUrl: Optional[str] = None
    technicalSkills: Optional[List[str]] = []
    softSkills: Optional[List[str]] = []
    educations: Optional[List[Dict[str, Any]]] = []
    workExperiences: Optional[List[Dict[str, Any]]] = []
    certificates: Optional[List[Dict[str, Any]]] = []
    projects: Optional[List[Dict[str, Any]]] = []
    resumeUrl: Optional[str] = None
    userId: Optional[str] = None
    profileCompletionPercentage: Optional[int] = None
    linkedin: Optional[str] = None
    github: Optional[str] = None
    portfolio: Optional[str] = None
    languages: Optional[List[str]] = []

# New model for applied candidates
class AppliedCandidateEducation(BaseModel):
    degree: Optional[str] = None
    endYear: Optional[str] = None
    fieldOfStudy: Optional[str] = None
    institution: Optional[str] = None
    startYear: Optional[str] = None

class AppliedCandidateWorkExperience(BaseModel):
    company: Optional[str] = None
    description: Optional[str] = None
    endDate: Optional[str] = None
    position: Optional[str] = None
    startDate: Optional[str] = None

class AppliedCandidate(BaseModel):
    applicantEmail: Optional[str] = None
    applicantName: Optional[str] = None
    applicantPhone: Optional[str] = None
    applicantProfileUrl: Optional[str] = None
    applicantResumeUrl: Optional[str] = None
    appliedAt: Optional[str] = None
    candidateId: Optional[str] = None
    companyName: Optional[str] = None
    educations: Optional[List[AppliedCandidateEducation]] = []
    jobId: Optional[str] = None
    jobTitle: Optional[str] = None
    languages: Optional[List[str]] = []
    location: Optional[str] = None
    softSkills: Optional[List[str]] = []
    status: Optional[str] = None
    technicalSkills: Optional[List[str]] = []
    workExperiences: Optional[List[AppliedCandidateWorkExperience]] = []

class JobDescription(BaseModel):
    position_summary: Optional[str] = None
    responsibilities: Optional[List[str]] = []
    required_skills: Optional[List[str]] = []
    preferred_skills: Optional[List[str]] = []
    technical_skills: Optional[Dict[str, List[str]]] = {}
    what_we_offer: Optional[List[str]] = []

class Job(BaseModel):
    id: Optional[str] = None
    title: Optional[str] = None
    company_name: Optional[str] = None
    location: Optional[str] = None
    job_type: Optional[str] = None
    description: Optional[JobDescription] = None
    required_skills: Optional[List[str]] = []
    responsibilities: Optional[List[str]] = []
    technical_skills: Optional[Dict[str, List[str]]] = {}
    recruiterId: Optional[str] = None
    contract_type: Optional[str] = None
    salary_range: Optional[str] = None
    last_date_to_apply: Optional[str] = None
    posted_on: Optional[str] = None
    preferred_skills: Optional[List[str]] = []
    what_we_offer: Optional[List[str]] = []

class MatchRequest(BaseModel):
    job: Job
    candidate: Candidate

class AppliedCandidateMatchRequest(BaseModel):
    job: Job
    applied_candidates: List[AppliedCandidate]

class DuplicateCheckRequest(BaseModel):
    applied_candidates: List[AppliedCandidate]
    similarity_threshold: Optional[float] = 0.85

class CategoryScore(BaseModel):
    required_skills: float
    qualification: float
    work_experience: float
    tech_stack: float

class MatchResponse(BaseModel):
    overall_match_score: float
    category_scores: CategoryScore