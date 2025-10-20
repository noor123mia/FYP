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

class JobDescription(BaseModel):
    position_summary: Optional[str] = None

class Job(BaseModel):
    id: Optional[str] = None
    title: Optional[str] = None
    company_name: Optional[str] = None
    location: Optional[str] = None
    job_type: Optional[str] = None
    description: Optional[Dict[str, Any]] = None
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

class CategoryScore(BaseModel):
    required_skills: float
    qualification: float
    work_experience: float
    tech_stack: float

class MatchResponse(BaseModel):
    overall_match_score: float
    category_scores: CategoryScore