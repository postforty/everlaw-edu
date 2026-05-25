package com.everlaw.edu.domain.progress;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface MemberWeaknessIndexRepository extends JpaRepository<MemberWeaknessIndex, Long> {
    
    Optional<MemberWeaknessIndex> findByMemberIdAndLawReference(Long memberId, String lawReference);
}
